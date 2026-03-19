{ pkgs, ... }: {
  channel = "stable-24.11";

  packages = [
    pkgs.docker
    pkgs.bore-cli
    pkgs.socat
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.sudo
    pkgs.netcat
  ];

  services.docker.enable = true;

  idx.workspace.onStart = {
    kali-rdp = ''
      set -e
      mkdir -p ~/kali-vps
      cd ~/kali-vps

      # 1. Chạy Container Kali Linux
      # Sử dụng bản rolling và cài đặt môi trường desktop + xrdp bên trong
      if ! docker ps -a --format '{{.Names}}' | grep -qx 'kali-vps'; then
        echo "⏳ Đang tải Kali Linux và thiết lập hệ thống (lần đầu sẽ hơi lâu)..."
        
        # Chạy container nền
        docker run --name kali-vps \
          --shm-size 2g -d \
          --cap-add=SYS_ADMIN \
          -p 3389:3389 \
          kalilinux/kali-rolling \
          sleep infinity

        # Cài đặt môi trường đồ họa và RDP server
        docker exec -u 0 kali-vps bash -c "
          apt update && 
          DEBIAN_FRONTEND=noninteractive apt install -y kali-desktop-xfce xrdp kali-linux-default &&
          useradd -m -s /bin/bash kali &&
          echo 'kali:12345678' | chpasswd &&
          echo 'root:12345678' | chpasswd &&
          service xrdp start
        "
      else
        docker start kali-vps || true
        docker exec -u 0 kali-vps service xrdp start || true
      fi

      # 2. Đợi port RDP (3389) sẵn sàng
      echo "⏳ Đang đợi Kali RDP server khởi động..."
      while ! nc -z localhost 3389; do sleep 1; done

      # 3. Chạy Bore để tạo Tunnel
      rm -f /tmp/bore.log
      nohup bore local 3389 --to bore.pub > /tmp/bore.log 2>&1 &

      sleep 5

      # 4. Lấy thông tin kết nối
      BORE_INFO=$(grep -o "listening at bore.pub:[0-9]*" /tmp/bore.log | head -n1)

      if [ -n "$BORE_INFO" ]; then
        PORT_ONLY=$(echo $BORE_INFO | cut -d':' -f2)
        
        echo "========================================="
        echo " 🐉 KALI LINUX RDP IS READY!"
        echo " 🖥️  Address: bore.pub"
        echo " 🔢 Port: $PORT_ONLY"
        echo " 👤 User: kali"
        echo " 🔑 Pass: 12345678"
        echo " -----------------------------------------"
        echo " Kết nối bằng Remote Desktop: bore.pub:$PORT_ONLY"
        echo "=========================================="
      else
        echo "❌ Lỗi: Bore không thể tạo tunnel. Kiểm tra /tmp/bore.log"
      fi

      # Giữ script sống
      while true; do sleep 60; done
    '';
  };

  idx.previews = {
    enable = false; # RDP không xem trực tiếp qua tab preview của IDX được
  };
}
