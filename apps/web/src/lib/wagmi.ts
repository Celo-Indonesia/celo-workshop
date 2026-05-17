import { createConfig, http, cookieStorage, createStorage, injected } from "wagmi";
import { celo, celoSepolia } from "wagmi/chains";

export const wagmiConfig = createConfig({
  chains: [celo, celoSepolia],
  connectors: [injected()],
  storage: createStorage({ storage: cookieStorage }),
  transports: {
    [celo.id]: http(),
    [celoSepolia.id]: http(),
  },
  ssr: true,
});
