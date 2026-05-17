"use client";

import { useState, useEffect } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract } from "wagmi";
import { parseUnits, erc20Abi } from "viem";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { jointVenturesConfig, CONTRACTS, WHITELISTED_TOKENS } from "@/lib/contracts";

export default function DepositPage() {
  const { address, isConnected } = useAccount();
  const [amount, setAmount] = useState("10");
  const [token, setToken] = useState(WHITELISTED_TOKENS[0]);

  // Cek allowance yang sudah di-approve
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: token.address,
    abi: erc20Abi,
    functionName: "allowance",
    args: address ? [address, CONTRACTS.JOINT_VENTURES] : undefined,
    query: { enabled: !!address },
  });

  // Step 1: Approve
  const { writeContract: approve, data: approveHash, isPending: isApproving } = useWriteContract();
  const { isLoading: isApproveConfirming, isSuccess: approveSuccess } = useWaitForTransactionReceipt({
    hash: approveHash,
  });

  const needsApproval = approveSuccess
    ? false
    : parseUnits(amount || "0", token.decimals) > ((allowance as bigint) ?? 0n);

  // Refetch allowance setelah approve confirmed
  useEffect(() => {
    if (approveSuccess) refetchAllowance();
  }, [approveSuccess]);

  // Step 2: Deposit
  const { writeContract: deposit, data: depositHash, isPending: isDepositing } = useWriteContract();
  const { isLoading: isDepositConfirming, isSuccess: depositSuccess } = useWaitForTransactionReceipt({ hash: depositHash });

  if (!isConnected) {
    return <p className="text-center mt-20 text-muted-foreground">Connect your wallet first.</p>;
  }

  return (
    <main className="flex justify-center items-center min-h-screen">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Deposit</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">

          {/* Pilih token */}
          <div className="flex gap-2">
            {WHITELISTED_TOKENS.map((t) => (
              <button
                key={t.address}
                onClick={() => setToken(t)}
                className={`flex-1 py-2 rounded-md text-sm font-medium border transition-colors ${
                  token.address === t.address
                    ? "bg-primary text-primary-foreground"
                    : "bg-background hover:bg-muted"
                }`}
              >
                {t.symbol}
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

          {/* Step 1: Approve */}
          {needsApproval ? (
            <Button
              onClick={() =>
                approve({
                  address: token.address,
                  abi: erc20Abi,
                  functionName: "approve",
                  args: [CONTRACTS.JOINT_VENTURES, parseUnits(amount, token.decimals)],
                })
              }
              disabled={isApproving || isApproveConfirming}
              className="w-full"
            >
              {isApproving ? "Waiting for wallet..." : isApproveConfirming ? "Approving..." : `1. Approve ${token.symbol}`}
            </Button>
          ) : (
            /* Step 2: Deposit */
            <Button
              onClick={() =>
                deposit({
                  ...jointVenturesConfig,
                  functionName: "deposit",
                  args: [token.address, parseUnits(amount, token.decimals)],
                })
              }
              disabled={isDepositing || isDepositConfirming}
              className="w-full"
            >
              {isDepositing ? "Waiting for wallet..." : isDepositConfirming ? "Confirming..." : "2. Deposit"}
            </Button>
          )}

          {approveSuccess && <p className="text-blue-500 text-sm text-center">Approved! Now click Deposit.</p>}
          {depositSuccess && <p className="text-green-500 text-sm text-center">Deposit successful!</p>}
        </CardContent>
      </Card>
    </main>
  );
}
