"use client";

import { useState } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits } from "viem";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { MockERC20Abi } from "@/lib/abis/MockERC20Abi";
import { CONTRACTS } from "@/lib/contracts";

const TOKENS = [
  { label: "MockUSDC", address: CONTRACTS.MOCK_USDC, decimals: 6 },
  { label: "MockUSDT", address: CONTRACTS.MOCK_USDT, decimals: 6 },
];

export default function MintPage() {
  const { address, isConnected } = useAccount();
  const [amount, setAmount] = useState("100");
  const [selectedToken, setSelectedToken] = useState(TOKENS[0]);

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  function handleMint() {
    writeContract({
      address: selectedToken.address,
      abi: MockERC20Abi,
      functionName: "mint",
      args: [address!, parseUnits(amount, selectedToken.decimals)],
    });
  }

  if (!isConnected) {
    return <p className="text-center mt-20 text-muted-foreground">Connect your wallet first.</p>;
  }

  return (
    <main className="flex justify-center items-center min-h-screen">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Mint Mock Token</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">

          {/* Pilih token */}
          <div className="flex gap-2">
            {TOKENS.map((token) => (
              <button
                key={token.address}
                onClick={() => setSelectedToken(token)}
                className={`flex-1 py-2 rounded-md text-sm font-medium border transition-colors ${
                  selectedToken.address === token.address
                    ? "bg-primary text-primary-foreground"
                    : "bg-background hover:bg-muted"
                }`}
              >
                {token.label}
              </button>
            ))}
          </div>

          {/* Input amount */}
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="Amount"
            className="w-full px-3 py-2 border rounded-md bg-background text-sm"
          />

          {/* Tombol mint */}
          <Button
            onClick={handleMint}
            disabled={isPending || isConfirming}
            className="w-full"
          >
            {isPending ? "Waiting for wallet..." : isConfirming ? "Confirming..." : `Mint ${selectedToken.label}`}
          </Button>

          {isSuccess && (
            <p className="text-green-500 text-sm text-center">
              Minted {amount} {selectedToken.label} successfully!
            </p>
          )}
        </CardContent>
      </Card>
    </main>
  );
}
