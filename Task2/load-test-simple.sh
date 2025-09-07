#!/bin/bash

# Простой скрипт для нагрузочного тестирования
# Генерирует нагрузку на приложение для тестирования HPA

SERVICE_URL="http://localhost:8080"

echo "=== Нагрузочное тестирование scaletestapp ==="
echo "Сервис: $SERVICE_URL"
echo ""

# Функция для получения количества подов
get_pod_count() {
    kubectl get pods -l app=scaletestapp --no-headers | wc -l
}

# Функция для получения метрик HPA
get_hpa_status() {
    echo "HPA Status:"
    kubectl get hpa scaletestapp-hpa
    echo ""
}

# Функция для получения метрик подов
get_pod_metrics() {
    echo "Pod Metrics:"
    kubectl top pods -l app=scaletestapp
    echo ""
}

# Функция для отправки запросов
send_requests() {
    local duration=$1
    local rate=$2
    echo "Отправка $rate запросов в секунду в течение $duration секунд..."
    
    for i in $(seq 1 $duration); do
        for j in $(seq 1 $rate); do
            curl -s $SERVICE_URL/ > /dev/null &
        done
        sleep 1
        echo -n "."
    done
    echo ""
    wait
}

echo "1. Начальное состояние:"
echo "Количество подов: $(get_pod_count)"
get_hpa_status
get_pod_metrics

echo "2. Создание нагрузки (10 RPS в течение 30 секунд):"
send_requests 30 10
echo ""
echo "Количество подов: $(get_pod_count)"
get_hpa_status
get_pod_metrics

echo "3. Создание высокой нагрузки (20 RPS в течение 60 секунд):"
send_requests 60 20
echo ""
echo "Количество подов: $(get_pod_count)"
get_hpa_status
get_pod_metrics

echo "4. Создание пиковой нагрузки (50 RPS в течение 30 секунд):"
send_requests 30 50
echo ""
echo "Количество подов: $(get_pod_count)"
get_hpa_status
get_pod_metrics

echo "5. Снижение нагрузки (ожидание масштабирования вниз):"
echo "Ожидание 60 секунд для стабилизации..."
sleep 60
echo "Количество подов: $(get_pod_count)"
get_hpa_status
get_pod_metrics

echo "=== Тестирование завершено ==="
