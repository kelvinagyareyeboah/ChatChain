
4. 👤 Select a user 
# Deploy to ICP mainnet

Ac
https://<ChatChain_front
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
