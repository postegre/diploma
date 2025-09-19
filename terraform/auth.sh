#!/usr/bin/env bash
# auth.sh — авторизация для Terraform в Yandex Cloud через пользовательский токен

# Убираем переменную для SA (если вдруг была)
unset YC_SERVICE_ACCOUNT_KEY_FILE

# Генерируем свежий токен
export YC_TOKEN=$(yc iam create-token)

# Подтягиваем cloud-id и folder-id из текущего профиля CLI
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)

echo "Авторизация обновлена:"
echo "YC_TOKEN=$(echo $YC_TOKEN | cut -c1-15)..."
echo "YC_CLOUD_ID=$YC_CLOUD_ID"
echo "YC_FOLDER_ID=$YC_FOLDER_ID"

