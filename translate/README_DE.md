<div align="center">
  <img src="../asset/ZET.png" alt="Zet Logo" width="700"/>
  
  <!-- Language Selection -->
  <p>
    <a href="../README.md">🇷🇺 Русский</a> | 
    <a href="README_EN.md">🇺🇸 English</a> | 
    <a href="README_CN.md">🇨🇳 中文</a> | 
    <strong>🇩🇪 Deutsch</strong>
  </p>
  
  <h1>ZetGui: Ihr AI Terminal & IDE</h1>
  <p><strong>Hören Sie auf, Befehle auswendig zu lernen. Beginnen Sie Gespräche mit Ihrem Terminal.</strong></p>
  <p>
    <a href="#"><img src="https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white" alt="TypeScript"></a>
    <a href="#"><img src="https://img.shields.io/badge/React-61DAFB?style=for-the-badge&logo=react&logoColor=black" alt="React"></a>
    <a href="#"><img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js"></a>
    <a href="#"><img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"></a>
    <a href="#"><img src="https://img.shields.io/badge/Neutralino-000000?style=for-the-badge" alt="Neutralino"></a>
  </p>
</div>

## 🤔 Warum ZetGui?

In einer Welt komplexer CLIs und endloser Flags bietet ZetGui eine revolutionäre Alternative: ein direktes Gespräch mit einem AI-Agenten, der in einer sicheren, isolierten Umgebung läuft. Es geht nicht nur darum, einen Befehl auszuführen; es geht darum, Aufgaben durch Dialog zu erfüllen.

| Funktion | Beschreibung |
|----------|--------------|
| 💬 **Natürliche Sprache** | Sagen Sie ZetGui einfach, was Sie tun möchten. "Python herunterladen, entpacken und zu PATH hinzufügen." Fertig. |
| 🛡️ **Standardmäßig sicher** | Jeder Befehl läuft in einem Sandbox-`ubuntu:24.04` Container. Ihr Host-OS ist immer sicher. |
| 🧠 **Transparente AI** | ZetGui zeigt Ihnen seinen Denkprozess und erklärt *warum* es einen bestimmten Befehl gewählt hat, bevor es ihn ausführt. |
| 🔧 **Vollständige IDE** | Eingebauter Code-Editor, Dateimanager und Terminal in einer Anwendung. |
| 📱 **Desktop + Web** | Funktioniert als Desktop-App (Neutralino) und im Browser. |

## 🚀 Wie es funktioniert

ZetGui arbeitet in einer einfachen, aber mächtigen Schleife:

1. **Sie:** Geben eine Aufgabe in einfacher Sprache vor
2. **ZetGui (AI):** Analysiert Ihre Anfrage, erstellt einen Plan und übersetzt ihn in einen präzisen Shell-Befehl
3. **ZetGui (Executor):** Führt den Befehl in der sicheren Docker-Sandbox aus
4. **Sie:** Sehen die Ausgabe und setzen das Gespräch fort

## ⚡️ Schnellstart

> **Voraussetzungen:** [Node.js](https://nodejs.org/) (v18+), [Docker](https://www.docker.com/) und lokal laufende [Kiala API](https://github.com/derxanax/Kiala-api-qwen).

### 1. Umgebung einrichten

```bash
# Projekt klonen
git clone https://github.com/derxanax/ZeroEnhanced.git
cd ZeroEnhanced

# Abhängigkeiten installieren
npm install

# Docker Sandbox erstellen (einmalig)
npm run setup
```

### 2. Backend starten

```bash
cd backend
npm install
npm run dev  # Läuft auf localhost:3003
```

### 3. Desktop App starten

```bash
cd desktop
npm install
npm run dev  # Startet Neutralino App
```

### 4. Oder Web Version starten

```bash
cd desktop/react-src
npm install
npm start   # Läuft auf localhost:3000
```

> **Hinweis:** Ein `/sandbox` Verzeichnis wird automatisch erstellt und mit dem Docker Container für Dateiaustausch geteilt.

## 🏗️ Architektur

```
ZeroEnhanced/
├── backend/           # Express.js API Server
├── desktop/           # Neutralino Desktop-Anwendung
│   └── react-src/     # React UI Komponenten
├── docker-sandbox/    # Docker Umgebung für Befehlsausführung
└── src/              # Kernlogik (CLI Version)
```

## 🛣️ Was kommt als Nächstes?

ZetGui ist eine sich entwickelnde Plattform. Hier geht es hin:

- [x] **Desktop-Anwendung** mit Neutralino
- [x] **Mehrsprachige Benutzeroberfläche**
- [ ] **Mehrstufige Ausführung:** Autonome Ausführung komplexer, mehrstufiger Workflows
- [x] **Web- und Dateioperationen:** Native Tools für die Interaktion mit APIs und dem Dateisystem
- [ ] **Persistenter Zustand:** Sandbox-Speicher zwischen Sitzungen
- [ ] **Plugin-System:** Erweiterbare Plugin-Architektur
- [ ] **Cloud-Sync:** Einstellungen und Projektsynchronisation

## 📝 Verwendungsbeispiele

### Entwicklung
```
Benutzer: "Erstelle ein neues React-Projekt mit TypeScript"
ZetGui: Erstelle React-Projekt mit TypeScript-Unterstützung...
$ npx create-react-app my-app --template typescript
```

### DevOps
```
Benutzer: "Überprüfe den Status aller Docker-Container und starte die gestoppten neu"
ZetGui: Überprüfe Docker-Container und starte gestoppte neu...
$ docker ps -a && docker start $(docker ps -aq --filter "status=exited")
```

### Systemadministration
```
Benutzer: "Finde alle Dateien größer als 100MB und zeige die Top 10"
ZetGui: Suche nach großen Dateien im System...
$ find / -type f -size +100M -exec du -h {} + 2>/dev/null | sort -rh | head -10
```

## 👥 Autoren

👤 **Sasha (zarazaex)**  
Telegram: [@zarazaex](https://t.me/zarazaex)

👤 **Derx / lyzt**  
Telegram: [@amyluutz](https://t.me/amyluutz)  
Mail: derx@derx.space

👤 **Alexey**

---

<div align="center">
  <p>Made with ❤️ by derx and zarazaex</p>
  
  <p>
    <a href="https://github.com/derxanax/ZeroEnhanced">⭐ Star on GitHub</a> |
    <a href="https://github.com/derxanax/ZeroEnhanced/issues">🐛 Report Bug</a> |
    <a href="https://github.com/derxanax/ZeroEnhanced/discussions">💬 Discussions</a>
  </p>
</div> 