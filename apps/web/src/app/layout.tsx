import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { headers } from "next/headers";
import { cookieToInitialState } from "wagmi";
import "./globals.css";

import { Navbar } from "@/components/navbar";
import { WalletProvider } from "@/components/wallet-provider";
import { wagmiConfig } from "@/lib/wagmi";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "celo-workshop-ugm",
  description: "A new Celo blockchain project",
};

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const initialState = cookieToInitialState(
    wagmiConfig,
    (await headers()).get("cookie")
  );

  return (
    <html lang="en">
      <body className={inter.className}>
        <div className="relative flex min-h-screen flex-col">
          <WalletProvider initialState={initialState}>
            <Navbar />
            <main className="flex-1">{children}</main>
          </WalletProvider>
        </div>
      </body>
    </html>
  );
}
