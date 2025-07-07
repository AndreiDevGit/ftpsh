#!/bin/bash

# Проверка на root-права
if [ "$(id -u)" -ne 0 ]; then
  echo "Ошибка: скрипт должен быть запущен от root (используйте sudo)." >&2
  exit 1
fi

# 1. Создание пользователей и домашних папок
echo "Создание пользователей и домашних папок..."
users=("user1" "user2" "user3")
for user in "${users[@]}"; do
  if id "$user" &>/dev/null; then
    echo "Пользователь $user уже существует. Пропускаем."
  else
    useradd -m -d "/home/$user" -s /bin/bash "$user"
    echo "Установите пароль для $user:"
    passwd "$user"
  fi
done

# 2. Создание общей папки FTPshare
echo "Создание общей папки /home/FTPshare..."
mkdir -p /home/FTPshare

# 3. Настройка прав доступа
echo "Настройка прав доступа..."
groupadd ftpgroup &>/dev/null || true  # Игнорируем ошибку, если группа уже есть
for user in "${users[@]}"; do
  usermod -aG ftpgroup "$user"
done

chgrp ftpgroup /home/FTPshare
chmod 775 /home/FTPshare
chmod g+s /home/FTPshare  # SGID, чтобы новые файлы наследовали группу

# 4. Настройка vsftpd
echo "Установка и настройка vsftpd..."
apt update && apt install -y vsftpd

# Конфигурация vsftpd
cat > /etc/vsftpd.conf <<EOF
listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pasv_min_port=40000
pasv_max_port=50000
user_sub_token=\$USER
local_root=/home/\$USER
EOF

# Создание символических ссылок на FTPshare
for user in "${users[@]}"; do
  ln -sf /home/FTPshare "/home/$user/FTPshare"
done

# Перезапуск vsftpd
systemctl restart vsftpd
systemctl enable vsftpd

# 5. Проверка работы
echo "Проверка настроек..."
echo "Список пользователей в группе ftpgroup:"
getent group ftpgroup
echo "Содержимое домашней папки user1:"
ls -la /home/user1
echo "Права на /home/FTPshare:"
ls -ld /home/FTPshare

echo "Готово! Настройка завершена."
echo "Для подключения используйте FTP-клиент с данными одного из пользователей: ${users[*]}"
echo "Общая папка доступна по ссылке ~/FTPshare в домашней директории каждого пользователя."