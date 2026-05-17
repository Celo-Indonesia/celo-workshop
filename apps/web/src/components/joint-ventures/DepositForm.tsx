"use client";

import { useState, useEffect } from "react";
import { useAccount, useReadContract } from "wagmi";
import { parseUnits, erc20Abi, formatUnits } from "viem";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useApprove, useDeposit } from "@/hooks/useJVWrite";
import { useIsMember } from "@/hooks/useJVRead";
import { CONTRACTS, WHITELISTED_TOKENS } from "@/lib/contracts";

export function DepositForm() {
  const { address, isConnected } = useAccount();
  const { isMember } = useIsMember(address);
  const [amount, setAmount] = useState("");
  const [selectedToken, setSelectedToken] = useState(WHITELISTED_TOKENS[0]);

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: selectedToken.address,
    abi: erc20Abi,
    functionName: "allowance",
    args: address ? [address, CONTRACTS.JOINT_VENTURES] : undefined,
    query: { enabled: !!address },
  });

  const { approve, isPending: isApproving, isConfirming: isApproveConfirming, isSuccess: approveSuccess } = useApprove(selectedToken.address);
  const { deposit, isPending: isDepositing, isConfirming: isDepositConfirming, isSuccess: depositSuccess } = useDeposit();

  useEffect(() => {
    if (approveSuccess) refetchAllowance();
  }, [approveSuccess]);

  const needsApproval = approveSuccess
    ? false
    : amount && allowance !== undefined
      ? parseUnits(amount || "0", selectedToken.decimals) > (allowance as bigint)
      : true;

  if (!isConnected || !isMember) return null;

  const allowanceFormatted = allowance ? Number(formatUnits(allowance as bigint, selectedToken.decimals)) : 0;

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle className="text-lg">Deposit</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex gap-2">
          {WHITELISTED_TOKENS.map((token) => (
            <button
              key={token.address}
              onClick={() => setSelectedToken(token)}
              className={`px-4 py-2 rounded-md text-sm font-medium border transition-colors ${
                selectedToken.address === token.address
                  ? "bg-primary text-primary-foreground border-primary"
                  : "bg-background border-input hover:bg-muted"
              }`}
            >
              {token.symbol}
            </button>
          ))}
        </div>

        <input
          type="number"
          placeholder="Amount"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          className="w-full px-3 py-2 border rounded-md bg-background text-sm"
          min="0"
        />

        <p className="text-xs text-muted-foreground">
          Approved: {allowanceFormatted.toFixed(2)} {selectedToken.symbol}
        </p>

        {needsApproval ? (
          <Button
            onClick={() => approve(amount, selectedToken.decimals)}
            disabled={!amount || isApproving || isApproveConfirming}
            className="w-full"
          >
            {isApproving ? "Waiting for wallet..." : isApproveConfirming ? "Approving..." : `Approve ${selectedToken.symbol}`}
          </Button>
        ) : (
          <Button
            onClick={() => deposit(selectedToken.address, amount, selectedToken.decimals)}
            disabled={!amount || isDepositing || isDepositConfirming}
            className="w-full"
          >
            {isDepositing ? "Waiting for wallet..." : isDepositConfirming ? "Confirming..." : "Deposit"}
          </Button>
        )}

        {approveSuccess && <p className="text-green-500 text-sm">Approved! Now you can deposit.</p>}
        {depositSuccess && <p className="text-green-500 text-sm">Deposit successful!</p>}
      </CardContent>
    </Card>
  );
}
