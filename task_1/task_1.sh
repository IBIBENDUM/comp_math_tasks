#!/usr/bin/env

# Реализация на bash + bc
# Скрипт для вычисления производной синуса и анализа погрешностей

set -eu # Защита от использования неопределенных переменных и ошибок

# --- Проверка зависимостей ---
check_dependencies() {
  local deps=("bc" "gnuplot")
  local missing=()

  for dep in ${deps[@]}; do 
    if ! command -v $dep > /dev/null 2>&1; then
      missing+=($dep)
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Ошибка: отсутствуют зависимости ${missing[*]}"
    echo "Попробуйте: sudo apt install ${missing[*]}"
    exit 1
  fi
}

check_dependencies

# --- Математические функции ---

# Обертка над bc
calc () { echo "scale=$BC_SCALE; $1" | bc -l; }

sin()   { calc "s($1)"; }
cos()   { calc "c($1)"; }
log10() { calc "l($1) / l(10)"; }
abs()   { calc "if ($1 < 0) -($1) else $1"; }
pow()   { calc "e(l($1) * $2)"; }

# --- Константы ---
readonly BC_SCALE=10
readonly PI=$(calc "4 * a(1)")
readonly DEFAULT_X_0=$(calc "$PI / 6")
readonly DEFAULT_DATA_FILE="derivative_data.csv"
readonly DEFAULT_PLOT_FILE="derivative_plot.png"
readonly PLOT_SCRIPT="plot.gp"

# --- Переопределяеммые переменные ---
X_0=$DEFAULT_X_0
DATA_FILE=$DEFAULT_DATA_FILE
PLOT_FILE=$DEFAULT_PLOT_FILE

DER_EXACT_VALUE=$(calc "c($X_0)")

# --- Вычисление производной ---
derivative_central() {
  local x=$1 h=$2
  local f_right=$(sin $(calc "$x + $h")) 
  local f_left=$(sin $(calc "$x - $h")) 
  calc "($f_right - $f_left) / (2 * $h)"
}

# --- Вспомогательные функции ---
cleanup() {
  if [[ -f $PLOT_SCRIPT ]]; then 
    echo "Очистка временных файлов..."
    rm -f $PLOT_SCRIPT
  fi
}

print_point_info(){
  echo "Анализ погрешностей численного дифференцирования"
  echo "Точка анализа: x ≈ $X_0"
  echo "Точное значение проивзодной: cos(π/6) = $DER_EXACT_VALUE"
}

print_help() {
    cat << EOF
Использование: $0 [ОПЦИИ]

Анализ погрешностей численного дифференцирования функции sin(x)

Опции:
  -h, --help            Показать эту справку и выйти
  -x, --x-point VALUE   Точка для анализа (по умолчанию: π/6 ≈ $DEFAULT_X_0)
  -d, --data-file FILE  Файл для данных CSV (по умолчанию: $DEFAULT_DATA_FILE)
  -p, --plot-file FILE  Файл для графика PNG (по умолчанию: $DEFAULT_PLOT_FILE)
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do 
    case $1 in
      -h | --help)
        print_help
        exit 0
        ;;
      
      -x | --x-point)
        if [[ -z $2 ]]; then
          echo "Ошибка: $1 требует последующее значение"
          exit 1
        fi
        X_0=$2
        shift 2
        ;;

      -d|--data-file)
          if [[ -z $2 ]]; then
              echo "Ошибка: $1 требует значение"
              exit 1
          fi
          DATA_FILE=$2
          shift 2
          ;;

      -p|--plot-file)
          if [[ -z $2 ]]; then
              echo "Ошибка: $1 требует значение" >&2
              exit 1
          fi
          PLOT_FILE=$2
          shift 2
          ;;

      *)
        print_help
        exit 1
        ;;

    esac
  done
}

# --- Основная программа ---
calc_der_error(){
  echo log_h log_error_central > $DATA_FILE

  echo "Вычисление погрешностей..."
  for log_h in $(seq -10 0.1 -2); do
    local h=$(pow 10 $log_h)
    local approx_central=$(derivative_central $X_0 $h)

    local error_central=$(abs $(calc "$approx_central - $DER_EXACT_VALUE"))
    local log_error_central=$(log10 $error_central)
    echo $log_h $log_error_central >> $DATA_FILE
  done

}

create_plot() {
    cat > $PLOT_SCRIPT << EOF
      # Настройки вывода
      set terminal pngcairo enhanced font "Arial,12" size 800,600
      set output "$PLOT_FILE"
     
      # Заголовки и подписи 
      set title "Зависимость погрешности от шага (x = π/6)"
      set xlabel "log₁₀(h)"
      set ylabel "log₁₀(погрешности)"
      
      # Сетка и легенда
      set grid
      set key top right

      # Построение графика
      plot "$DATA_FILE" using 1:2 with linespoints title "Центральная разность"
EOF

    gnuplot $PLOT_SCRIPT 2>/dev/null
}

main () {
  # Обработчик отчистки на выходе
  trap cleanup EXIT INT TERM

  # Парсинг аргументов
  parse_args "$@"

  print_point_info
  calc_der_error
  create_plot
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
