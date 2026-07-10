
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


