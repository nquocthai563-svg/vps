{ pkgs, ... }: {
  channel = "stable-24.11";

  packages = [
    pkgs.docker
    pkgs.cloudflared
    pkgs.socat
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.unzip
    pkgs.netcat
  ];

  services.docker.enable = true;

  idx.workspace.onStart = {
    windows-tiny = ''
      set -e
      mkdir -p ~/win-data
      cd ~/win-data

      # Khởi tạo Container Windows Tiny
      # VERSION: tiny11 (Bản rút gọn siêu nhẹ của Windows 11)
      # RAM: 60G (Theo yêu cầu của Thống soái)
      if ! docker ps -a --format '{{.Names}}' | grep -qx 'windows-tiny'; then
        docker run --name windows-tiny -d \
          --device=/dev/kvm \
          --cap-add=NET_ADMIN \
          -p 3389:3389 \
          -p 8006:8006 \
          -e VERSION="tiny11" \
          -e RAM_SIZE="60G" \
          -e CPU_CORES="4" \
          -e USERNAME="oanhchaovunha" \
          -e PASSWORD="thai211213" \
          --stop-timeout 2 minutes \
          dockurr/windows
      else
        docker start windows-tiny || true
      fi

      # Chờ cổng RDP (3389) sẵn sàng
      echo "--- Đang khởi động động cơ Windows (60GB RAM) ---"
      while ! nc -z localhost 3389; do sleep 2; done

      # Kích hoạt Cloudflared Tunnel cho cổng RDP
      nohup cloudflared tunnel --no-autoupdate --url tcp://localhost:3389 \
        > /tmp/cloudflared_rdp.log 2>&1 &

      sleep 10

      # Trích xuất URL Cloudflare cho Thống soái
      URL=""
      for i in {1..20}; do
        URL=$(grep -o "tcp://[a-z0-9.-]*trycloudflare.com:[0-9]*" /tmp/cloudflared_rdp.log | head -n1)
        if [ -n "$URL" ]; then break; fi
        sleep 2
      done

      if [ -n "$URL" ]; then
        echo "========================================="
        echo " 🛡️ WINDOWS RDP READY 🛡️"
        echo " 🔗 Link kết nối: $URL"
        echo " 👤 User: oanhchaovunha"
        echo " 🔑 Pass: thai211213"
        echo "=========================================="
      else
        echo "❌ Tunnel thất bại, kiểm tra /tmp/cloudflared_rdp.log"
      fi

      # Giữ script sống
      while true; do sleep 60; done
    '';
  };

  idx.previews = {
    enable = true;
    previews = {
      # Preview này cho phép Ngài xem quá trình cài đặt qua trình duyệt (Port 8006)
      install-view = {
        manager = "web";
        command = [
          "socat" "TCP-LISTEN:$PORT,fork,reuseaddr" "TCP:127.0.0.1:8006"
        ];
      };
    };
  };
}
