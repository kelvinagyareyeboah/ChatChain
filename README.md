
├── 📄 dfx.json
├── 📄 package.json
├── 📄 webpack.config.js
└── 

## ⚡ Getting Started

### Prerequisites

![DFX](https://img.shields.io/badge/DFX-v0.15+-29ABE2?style=flat-square)
![Node](https://img.shields.io/badge/Node.js-≥16-339933?style=flat-square&logo=nodedotjs&logoColor=white)
![Git](https://img.shields.io/badge/Git-required-F05032?style=flat-square&logo=
```bash
# Install DFX SDK
sh -ci "$(curl -fsSL https://smartcontracts.org/install.sh)"
```

- **Node.js** ≥ 16 — [Download](https://nodejs.org)
- **Internet Identity** — [identity.ic0.app](https://identity.ic0.app) or deploy locally

---

### 🔧 Local Setup

```bash
# 1. Clone the repository
git clone https://github.com/KelvCodes/ChatChain.git
cd ChatChain

# 2. Install dependencies
npm install

# 3. Start the local ICP replica
dfx start --background

# 4. Deploy canisters locally
dfx deploy
```

### 5. Set Your Canister ID

In `src/frontend/assets/js/index.js`, update:

```js
// Replace with your actual backend canister ID
const canisterId = 'ryjl3-tyaaa-aaaaa-aaaba-cai';
const host = 'http://127.0.0.1:4943';
```

### 6. Launch the Frontend

```bash
npm start
```

Open [http://localhost:9000](http://localhost:9000) in your browser.

---

## 🧪 Testing the App

1. 🌐 Open the app in your browser
2. ⚙️ Click the gear icon to log in via **Internet Identity**
3. 📝 Enter a username to register
4. 👤 Select a user from the list to start chatting
5. 💬 Send messages — they're stored in the canister and refreshed every 5 seconds

---

## 🚀 Deployment to ICP Mainnet

```bash
# Deploy to ICP mainnet
dfx deploy --network ic
```

Update `index.js` with your mainnet config:

```js
const canisterId = 'YOUR_IC_CANISTER_ID';
const host = 'https://icp-api.io';
```

Access your live app at:

```
https://<ChatChain_frontend_id>.icp0.io
```

Or host the frontend on Vercel and point it to the mainnet backend canister.

---

## 🛠️ Development Notes

### Internet Identity (Local)

```bash
dfx deploy internet_identity --network local
```

Update `index.js` with the local Identity canister ID for testing.

### Regenerate Canister Bindings

After modifying `main.mo`:

```bash
dfx generate ChatChain_backend
```

### Reset Local State

```bash
dfx start --clean --background
```

---

## 🔮 Extending ChatChain

| Feature | Approach |
|---|---|
| 🔒 Private Messaging | Include recipient Principals in message types |
| 📄 Pagination | Add offset/limit params to message queries |
| 🗑️ Message Deletion | Add delete method to canister with auth checks |
| 📁 File Uploads | Store metadata on-chain; large files may need multiple canisters |
| ⚡ Real-Time | Explore ICP PubSub patterns when available |

---

## ⚠️ Known Limitations

| Issue | Details |
|---|---|
| 🕐 Polling Delay | Not fully real-time — messages refresh every 5 seconds |
| 🟢 Static Online Status | All users appear "online" — needs real-time tracking |
| 💾 In-Memory Storage | All messages stored in-memory; add pagination for production |
| 🔓 Auth Enforcement | Unregistered users can message — enforce auth in `registerUser` |

---

## 📦 Dependencies

### Backend
- **Motoko** — via DFX SDK
- **Internet Computer SDK (DFX)**

### Frontend
```bash
@dfinity/agent         # Canister interaction
@dfinity/auth-client   # Internet Identity authentication
@dfinity/identity      # Principal management
webpack                # Module bundling
html-webpack-plugin    # HTML templating
css-loader             # CSS processing
copy-webpack-plugin    # Static asset copying
```

Install everything with:

```bash
npm install
```

---

## 🤝 Contributing

[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square)](CONTRIBUTING.md)
[![GitHub issues](https://img.shields.io/github/issues/KelvCodes/ChatChain?style=flat-square)](https://github.com/KelvCodes/ChatChain/issues)
[![GitHub stars](https://img.shields.io/github/stars/KelvCodes/ChatChain?style=flat-square)](https://github.com/KelvCodes/ChatChain/stargazers)

All contributions are welcome — bug fixes, new features, docs, or ideas.

```bash
# 1. Fork the repo
# 2. Create your feature branch
git checkout -b feature/your-feature

# 3. Commit your changes
git commit -m "Add your feature"

# 4. Push and open a Pull Request
git push origin feature/your-feature
```

---

## 📄 License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)

MIT — free to use, modify, and distribute. See [`LICENSE`](LICENSE) for details.

---

<div align="center">

*Built with 🖤 on the Internet Computer — no servers, no limits.*

[![GitHub](https://img.shields.io/badge/GitHub-KelvCodes-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/KelvCodes)

</div>
