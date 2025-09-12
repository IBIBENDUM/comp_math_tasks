#!/usr/bin/env

# Реализация на bash + bc
# Скрипт для вычисления производной синуса и анализа погрешностей

PI=$(echo "4 * a(1)" | bc -l)
X_0=$(echo "$PI / 6" | bc -l)
DER_EXACT_VALUE=$(echo "c($X_TEST)" | bc -l)

derivative_central() {
  local x=$1 h=$2
  local f_right=$(echo "s($x + $h)" | bc -l) 
  local f_left=$(echo "s($x - $h)" | bc -l) 
  echo "($f_right - $f_left) / (2 * $h)" | bc -l 
}

abs() {
  echo "if ($1 < 0) -($1) else $1" | bc -l
}

main () {
  echo "Анализ погрешностей численного дифференцирования"
  echo "π = $PI"
  echo "Точка анализа: x = π/6 ≈ $X_0"
  echo "Точное значение: cos(π/6) = $DER_EXACT_VALUE"

  local data_file="derivative_data.csv"
  echo log_h log_error_central > $data_file

  for log_h in $(seq -10 2 -2); do
    local h=$(echo "10^$log_h" | bc -l)
    local approx_central=$(derivative_central $X_0 $h)

    local error_central=$(abs $(echo "$approx_central - $DER_EXACT_VALUE" | bc -l))
    # echo $error_central
    local log_error_central=$(echo "l($error_central)/l(10)" | bc -l)
    echo $log_h $log_error_central >> $data_file
  done
}

main
