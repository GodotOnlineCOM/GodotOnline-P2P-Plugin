pipeline {
    agent {
        docker {
            image 'godot-build-image' // Docker için özel image kullanıyoruz
            args '--rm'
        }
    }
    environment {
        DISPLAY = ":0" // Bazı grafik bağımlılıkları için
    }
    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/GodotOnlineCOM/GodotOnline-P2P-Plugin.git'
            }
        }
        stage('Build') {
            steps {
                sh '/usr/local/bin/Godot_v4.4.1-stable_linux.x86_64 --headless --export Linux/X11'
            }
        }
    }
}
