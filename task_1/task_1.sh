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

main () {
  echo "Анализ погрешностей численного дифференцирования"
  echo "π = $PI"
  echo "Точка анализа: x = π/6 ≈ $X_0"
  echo "Точное значение: cos(π/6) = $DER_EXACT_VALUE"
  derivative_central $X_0 0.001
}

main
