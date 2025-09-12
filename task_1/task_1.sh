#!/usr/bin/env

# Реализация на bash + bc
# Скрипт для вычисления производной синуса и анализа погрешностей

set -eu # Защита от использования неопределенных переменных и ошибок

PI=$(echo "4 * a(1)" | bc -l)
X_0=$(echo "$PI / 6" | bc -l)
DER_EXACT_VALUE=$(echo "c($X_0)" | bc -l)

derivative_central() {
  local x=$1 h=$2
  local f_right=$(echo "s($x + $h)" | bc -l) 
  local f_left=$(echo "s($x - $h)" | bc -l) 
  echo "($f_right - $f_left) / (2 * $h)" | bc -l 
}

abs() {
  echo "if ($1 < 0) -($1) else $1" | bc -l
}

print_point_info(){
  echo "Анализ погрешностей численного дифференцирования"
  echo "π = $PI"
  echo "Точка анализа: x = π/6 ≈ $X_0"
  echo "Точное значение: cos(π/6) = $DER_EXACT_VALUE"
}

calc_der_error(){
  local data_file="derivative_data.csv"
  echo log_h log_error_central > $data_file

  for log_h in $(seq -10 0.1 -2); do
    local h=$(echo "e($log_h * l(10))" | bc -l)
    local approx_central=$(derivative_central $X_0 $h)

    local error_central=$(abs $(echo "$approx_central - $DER_EXACT_VALUE" | bc -l))
    local log_error_central=$(echo "l($error_central)/l(10)" | bc -l)
    echo $log_h $log_error_central >> $data_file
  done

}

create_plot() {
    cat > plot.gp << 'EOF'
set terminal pngcairo enhanced font "Arial,12" size 800,600
set output "derivative_plot.png"
set title "Зависимость погрешности от шага (x = π/6)"
set xlabel "log₁₀(h)"
set ylabel "log₁₀(погрешности)"
set grid
set key top right

plot "derivative_data.csv" using 1:2 with linespoints title "Центральная разность"
EOF
    
    gnuplot plot.gp 2>/dev/null
    rm -f plot.gp
}

main () {
  print_point_info
  calc_der_error
  create_plot
}

main
