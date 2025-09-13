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
    echo -e "${RED}Ошибка${NC}: отсутствуют зависимости ${missing[*]}"
    echo -e "${YELLOW}Попробуйте${NC}: sudo apt install ${missing[*]}"
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

# Вычисление выражений содержащих PI
eval_math_expression() {
  local expr=$1

  expr=${expr//π/$PI}

  expr=${expr// /}

  calc "$expr"
}

# --- Константы ---
readonly DEFAULT_BC_SCALE=10
readonly DEFAULT_DATA_FILE="derivative_data.csv"
readonly DEFAULT_PLOT_FILE="derivative_plot.png"
readonly PLOT_SCRIPT="plot.gp"
readonly DEFAULT_X_EXPRESSION="π/6"

if [[ -t 1 ]]; then
  # Вывод в терминал
  readonly RED='\033[0;31m'
  readonly YELLOW='\033[1;33m'
  readonly NC='\033[0m' # No Color
else
  # Вывод в файл
  readonly RED=''
  readonly YELLOW=''
  readonly NC='' 
fi

# --- Переопределяеммые переменные ---
BC_SCALE=$DEFAULT_BC_SCALE
X_EXPRESSION=$DEFAULT_X_EXPRESSION
X_0=""
PI=""
X_0=""
DER_EXACT_VALUE=""
DATA_FILE=$DEFAULT_DATA_FILE
PLOT_FILE=$DEFAULT_PLOT_FILE

# --- Вспомогательные функции ---
init_math_constants() {
  PI=$(calc "4 * a(1)")

  X_0=$(eval_math_expression "$X_EXPRESSION")

  DER_EXACT_VALUE=$(cos "$X_0")
}

cleanup() {
  if [[ -f $PLOT_SCRIPT ]]; then 
    echo "Очистка временных файлов..."
    rm -f $PLOT_SCRIPT
  fi
}

start_spinner() {
  local spin="⣾⣷⣯⣟⡿⢿⣻⣽"
  local i=0
  while true; do
    i=$(( (i+1) % ${#spin} ))
    printf "\r${spin:$i:1} $1"
    sleep 0.1
  done
}

stop_spinner() {
    local pid=$1
    kill "$pid" 2>/dev/null
    printf "\n"
}

print_point_info(){
  echo "Анализ погрешностей численного дифференцирования"
  echo "Точка анализа: x = $X_EXPRESSION ≈ $X_0"
  echo "Точное значение производной: cos(π/6) = $DER_EXACT_VALUE"
  echo "Сравниваемые методы:"
  echo "  1. Правая разность: F(x+h) - F(x) / h"
  echo "  2. Центральная разность: F(x+h) - F(x-h) / 2h"
  echo "  3. Вторая разность: (3F(x) - 4F(x-h) + F(x-2h)) / 2h"
}

print_help() {
    cat << EOF
Использование: $0 [ОПЦИИ]

Анализ погрешностей численного дифференцирования функции sin(x)

Опции:
  -h, --help            Показать эту справку и выйти
  -x, --x-point VALUE   Точка для анализа (по умолчанию: π/6)
  -d, --data-file FILE  Файл для данных CSV (по умолчанию: $DEFAULT_DATA_FILE)
  -p, --plot-file FILE  Файл для графика PNG (по умолчанию: $DEFAULT_PLOT_FILE)
Примеры:
  $0 -x "pi/6"           
  $0 -x "π/4"            
  $0 -x "sqrt(2)/2"         
  $0 -x "pi/6 + 0.1"     
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
        if [[ $# -lt 2 || -z $2 ]]; then
          echo -e "${RED}Ошибка${NC}: $1 требует значение"
          exit 1
        fi
        X_EXPRESSION="${2//pi/π}"
        shift 2
        ;;

      -d|--data-file)
          if [[ $# -lt 2 || -z $2 ]]; then
              echo -e "${RED}Ошибка${NC}: $1 требует значение"
              exit 1
          fi
          DATA_FILE=$2
          shift 2
          ;;

      -p|--plot-file)
          if [[ -z $2 ]]; then
              echo -e "${RED}Ошибка${NC}: $1 требует значение" 
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
# F(x+h) - F(x) / h
derivative_forward() {
  local x=$1 h=$2
  local f_right=$(sin $(calc "$x + $h")) 
  local f_x=$(sin "$x")
  calc "($f_right - $f_x) / $h"
}

# F(x+h) - F(x-h) / 2h
derivative_central() {
  local x=$1 h=$2
  local f_right=$(sin $(calc "$x + $h")) 
  local f_left=$(sin $(calc "$x - $h")) 
  calc "($f_right - $f_left) / (2 * $h)"
}

# 3F(x) - 4F(x-h) + F(x-2h)) / 2h
derivative_second_order() {
  local x=$1 h=$2
  local f_x=$(sin "$x")
  local f_minus_h=$(sin $(calc "$x - $h"))
  local f_minus_2h=$(sin $(calc "$x - 2 * $h"))
  calc "(3 * $f_x - 4 * $f_minus_h + $f_minus_2h) / (2 * $h)"
}


calc_der_error(){
  echo "log_h,error_forward,error_central,error_second_order" > $DATA_FILE

  start_spinner "Вычисление погрешностей..."&
  local spinner_pid=$!
  
  local methods=("derivative_forward" "derivative_central" "derivative_second_order")
  for log_h in $(seq -10 0.1 -0.1); do
    local h=$(pow 10 $log_h)
    local line="$log_h"

    for method in "${methods[@]}"; do
      local approx=$($method "$X_0" "$h")
      local error=$(abs "$(calc "$approx - $DER_EXACT_VALUE")")
      local log_error=$(log10 "$error")
      line="$line,$log_error"
    done
    
    echo "$line" >> "$DATA_FILE"
  done

  stop_spinner "$spinner_pid"
}

create_plot() {
  echo "Построение графика..."
    cat > $PLOT_SCRIPT << EOF
      # Настройки вывода
      set terminal pngcairo enhanced font "Arial,12" size 800,600
      set output "$PLOT_FILE"
     
      # Заголовки и подписи 
      set title "Зависимость погрешности от шага (x = $X_EXPRESSION)"
      set xlabel "log₁₀(h)"
      set ylabel "log₁₀(погрешности)"
      
      # Сетка и легенда
      set grid
      set key top right
      set datafile separator comma

      # Построение графика
      plot "$DATA_FILE" using 1:2 with linespoints title "Правая разность", \
           "$DATA_FILE" using 1:3 with linespoints title "Центральная разность", \
           "$DATA_FILE" using 1:4 with linespoints title "Вторая разность"
EOF

    gnuplot $PLOT_SCRIPT 2>/dev/null
}

main () {
  check_dependencies

  # Обработчик отчистки на выходе
  trap cleanup EXIT INT TERM

  # Парсинг аргументов
  parse_args "$@"
  init_math_constants

  print_point_info
  calc_der_error
  create_plot
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
