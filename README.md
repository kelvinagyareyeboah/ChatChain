n 
    U
s
tps://img.shields.io/badge/-Motoko-6B4FBB?style=flat-square) |
| Blockchain | ![ICP](https://img.shields.io/badge/-Internet_Computer-29ABE2?style=flat-square&logo=dfinity&l| Frontend | ![JavaScript](https://img.shields.io/badge/-JavaS1E?style=flat-square&logo=javascript&logoColor=black) ![HTML5](https://img.shields.io/badge/-HTML5-E34F26?style=flat-square&logo=htm) ![CSS3](https://img.shields.io/badge/-CSS3-1572B6?style=flat-sqlogoColor=white) |
| Bundler | ![Webpack](https://img.shields.io/badge/
| ICP libraries | `@dfinity/agent`, `@d`, `@df
## Deploy to Mainnet

```bash
dfx deploy --network ic
```

Update `index.js` with your mainnet values:

```js
const canisterId = '<your-mainnet-backend-canister-id>';
const host = 'https://icp-api.io';
```

Your app will be live at `https://<frontend-canister-id>.icp0.io`. You can also host the frontend elsewhere (for example on Vercel) and point it at the mainnet backend canister.

> [!IMPORTANT]
> Mainnet deploys cost cycles. Make sure your cycles wallet is funded before running `dfx deploy --network ic`.

## Development Notes

<details>
<summary><b>Run Internet Identity locally</b></summary>

```bash
dfx deploy internet_identity --network local
```

Then update `index.js` with the local Internet Identity canister ID.

</details>

<details>
<summary><b>Regenerate canister bindings</b></summary>

Run this after changing `main.mo`:

```bash
dfx generate ChatChain_backend
```

</details>

<details>
<summary><b>Reset local state</b></summary>

```bash
dfx start --clean --background
```

</details>

## Known Limitations

> [!WARNING]
> ChatChain is a learning project and is not production-ready yet.

| Limitation | Details |
|---|---|
| Polling | Updates arrive every 5 seconds, not instantly |
| Online status | All users appear online, as there is no presence tracking |
| Storage | Data is held in memory, so it can be lost on canister upgrade unless moved to stable storage |
| Auth checks | Unregistered users can still send messages. `registerUser` should enforce this |

## Roadmap

- [x] Internet Identity login
- [x] User registration
- [x] On-canister messaging
- [x] Polling for new messages
- [ ] Stable storage so data survives upgrades
- [ ] Enforce registration before messaging
- [ ] Private messages scoped to recipient principals
- [ ] Pagination for message history
- [ ] Message deletion with auth checks
- [ ] Real online and offline presence
- [ ] File sharing (metadata on-chain, large files across canisters)

## Contributing

Contributions are welcome, whether it's a bug fix, a feature, docs, or an idea.

```bash
git checkout -b feature/your-feature
git commit -m "Add your feature"
git push origin feature/your-feature
```

Then open a Pull Request.

## License

Released under the [MIT License](LICENSE).

<div align="center">

<br />

Built with 🖤 on the Internet Computer. No servers, no limits.

[![GitHub](https://img.shields.io/badge/-KelvCodes-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/KelvCodes)

⭐ **Star this repo if you like decentralized apps.**

</div>
