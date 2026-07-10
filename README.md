 log in using In every 5 seconds.

---

## 🚢 Deployment to ICP Mainnet

### 1. Deploy to Mainnet

```bash
dfx deploy --network ic
```

### 2. Update Canister ID & Host

Update `index.js`:

```js
const canisterId = 'YOUR_ic_CANISTER_ID';
const host = 'https://icp-api.io';
```

### 3. Access the App

Visit:

```
https://<ChatChain_frontend_id>.icp0.io
```

Or host the frontend statically (e.g., on Vercel) and point it to the backend.

---

## 🛠 Development Notes

### Internet Identity

Use [https://identity.ic0.app](https://identity.ic0.app) for auth. For local testing:

```bash
dfx deploy internet_identity --network local
```

Update `index.js` with the local Identity canister ID.

### Regenerate Canister Bindings

After modifying `main.mo`:

```bash
dfx generate ChatChain_backend
```

### Frontend Bundling

Webpack outputs to `dist/`. Ensure `webpack.config.js` includes `declarations/`.

### Local Testing

Set:

```js
const host = 'http://127.0.0.1:4943';
```

To reset local:

```bash
dfx start --clean --background
```

---

## 🔄 Extending Functionality

* **Private Messaging**: Include recipient Principals in message types.
* **Message Deletion/Pagination**: Add for scalability.
* **File Uploads**: Store metadata (large files may need multiple canisters).

---

## 📦 Dependencies

### Backend

* **Motoko** (via DFX)
* **Internet Computer SDK (DFX)**

### Frontend

* `@dfinity/agent` – Canister interactions
* `@dfinity/auth-client` – Internet Identity authentication
* `@dfinity/identity` – Principal management
* `webpack`, `webpack-cli`, `webpack-dev-server` – Bundling
* `html-webpack-plugin`, `css-loader`, `style-loader`, `copy-webpack-plugin` – Webpack setup
* `font-awesome` – Icons (via CDN)

Install all with:

```bash
npm install
```

---

## ⚠️ Known Limitations

* **Polling Delay**: Not fully real-time. Explore PubSub when available.
* **Static Online Status**: Users always appear "online." Improve via real-time tracking.
* **Memory Storage**: All messages stored in-memory. Add pagination or archiving for production.
* **Anonymous Messages**: Unregistered users can message. Enforce auth in `registerUser`.

---

## 🤝 Contributing

Contributions are welcome!

```bash
# Fork the repo
git checkout -b feature/your-feature
# Make changes
git commit -m 'Add your feature'
git push origin feature/your-feature
```

Then, open a **Pull Request** on GitHub.

---

## 📄 License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.

---

## 📬 Contact

For questions or support, open an issue or reach out to the maintainers.

```


