<div align="center">
  <img src="../asset/ZET.png" alt="Zet Logo" width="700"/>
  
  <!-- Language Selection -->
  <p>
    <a href="../README.md">🇷🇺 Русский</a> | 
    <a href="README_EN.md">🇺🇸 English</a> | 
    <strong>🇨🇳 中文</strong> | 
    <a href="README_DE.md">🇩🇪 Deutsch</a>
  </p>
  
  <h1>ZetGui: 您的AI终端和IDE</h1>
  <p><strong>停止记忆命令，开始与您的终端对话。</strong></p>
  <p>
    <a href="#"><img src="https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white" alt="TypeScript"></a>
    <a href="#"><img src="https://img.shields.io/badge/React-61DAFB?style=for-the-badge&logo=react&logoColor=black" alt="React"></a>
    <a href="#"><img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js"></a>
    <a href="#"><img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"></a>
    <a href="#"><img src="https://img.shields.io/badge/Neutralino-000000?style=for-the-badge" alt="Neutralino"></a>
  </p>
</div>

## 🤔 为什么选择ZetGui？

在复杂CLI和无穷标志的世界中，ZetGui提供了一个革命性的替代方案：与在安全隔离环境中运行的AI代理直接对话。这不仅仅是运行一个命令；而是通过对话完成任务。

| 功能 | 描述 |
|------|------|
| 💬 **自然语言** | 只需告诉ZetGui您想做什么。"下载Python，解压并添加到PATH。"完成。 |
| 🛡️ **默认安全** | 每个命令都在沙箱化的`ubuntu:24.04`容器中运行。您的主机操作系统始终安全。 |
| 🧠 **透明AI** | ZetGui向您展示其思考过程，解释*为什么*在运行之前选择特定命令。 |
| 🔧 **完整IDE** | 在一个应用程序中内置代码编辑器、文件管理器和终端。 |
| 📱 **桌面+网页** | 作为桌面应用程序（Neutralino）和浏览器中工作。 |

## 🚀 工作原理

ZetGui在一个简单而强大的循环中运行：

1. **您：** 用普通语言提供任务
2. **ZetGui（AI）：** 分析您的请求，制定计划，并将其转换为精确的shell命令
3. **ZetGui（执行器）：** 在安全的Docker沙箱内运行命令
4. **您：** 查看输出并继续对话

## ⚡️ 快速开始

> **先决条件：** [Node.js](https://nodejs.org/)（v18+）、[Docker](https://www.docker.com/)和本地运行的[Kiala API](https://github.com/derxanax/Kiala-api-qwen)。

### 1. 设置环境

```bash
# 克隆项目
git clone https://github.com/derxanax/ZeroEnhanced.git
cd ZeroEnhanced

# 安装依赖
npm install

# 构建Docker沙箱（一次性）
npm run setup
```

### 2. 运行后端

```bash
cd backend
npm install
npm run dev  # 在localhost:3003上运行
```

### 3. 运行桌面应用

```bash
cd desktop
npm install
npm run dev  # 启动Neutralino应用
```

### 4. 或运行Web版本

```bash
cd desktop/react-src
npm install
npm start   # 在localhost:3000上运行
```

> **注意：** `/sandbox`目录会自动创建并与Docker容器共享以进行文件交换。

## 🏗️ 架构

```
ZeroEnhanced/
├── backend/           # Express.js API服务器
├── desktop/           # Neutralino桌面应用程序
│   └── react-src/     # React UI组件
├── docker-sandbox/    # 命令执行的Docker环境
└── src/              # 核心逻辑（CLI版本）
```

## 🛣️ 未来计划

ZetGui是一个不断发展的平台。我们的发展方向：

- [x] **桌面应用程序** 使用Neutralino
- [x] **多语言界面**
- [ ] **多步执行：** 复杂多命令工作流的自主执行
- [x] **Web和文件操作：** 用于与API和文件系统交互的原生工具
- [ ] **持久状态：** 会话之间的沙箱内存
- [ ] **插件系统：** 可扩展的插件架构
- [ ] **云同步：** 设置和项目同步

## 📝 使用示例

### 开发
```
用户："创建一个带TypeScript的新React项目"
ZetGui：正在创建带TypeScript支持的React项目...
$ npx create-react-app my-app --template typescript
```

### DevOps
```
用户："检查所有Docker容器的状态并重启已停止的容器"
ZetGui：正在检查Docker容器并重启已停止的容器...
$ docker ps -a && docker start $(docker ps -aq --filter "status=exited")
```

### 系统管理
```
用户："查找所有大于100MB的文件并显示前10个"
ZetGui：正在系统中搜索大文件...
$ find / -type f -size +100M -exec du -h {} + 2>/dev/null | sort -rh | head -10
```

## 👥 作者

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