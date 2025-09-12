#!/usr/bin/env

# Реализация на bash + bc
# Скрипт для вычисления производной синуса и анализа погрешностей

set -eu # Защита от использования неопределенных переменных и ошибок

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
readonly X_0=$(calc "$PI / 6")
readonly DER_EXACT_VALUE=$(calc "c($X_0)")
readonly DATA_FILE="derivative_data.csv"
readonly PLOT_FILE="derivative_data.png"

# --- Вычисление производной ---
derivative_central() {
  local x=$1 h=$2
  local f_right=$(sin $(calc "$x + $h")) 
  local f_left=$(sin $(calc "$x - $h")) 
  calc "($f_right - $f_left) / (2 * $h)"
}

# --- Основная программа ---
print_point_info(){
  echo "Анализ погрешностей численного дифференцирования"
  echo "π = $PI"
  echo "Точка анализа: x = π/6 ≈ $X_0"
  echo "Точное значение: cos(π/6) = $DER_EXACT_VALUE"
}

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
    cat > plot.gp << EOF
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

    gnuplot plot.gp 2>/dev/null
}

main () {
  print_point_info
  calc_der_error
  create_plot
}

main
