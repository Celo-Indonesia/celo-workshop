"use client";

import { useState } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract } from "wagmi";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { jointVenturesConfig } from "@/lib/contracts";

export default function RegisterPage() {
  const { address, isConnected } = useAccount();
  const [name, setName] = useState("");

  // Cek apakah sudah jadi member
  const { data: memberData } = useReadContract({
    ...jointVenturesConfig,
    functionName: "members",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });
  const isMember = (memberData as [string, bigint, boolean] | undefined)?.[2] ?? false;
  const memberName = (memberData as [string, bigint, boolean] | undefined)?.[0] ?? "";

  // Write ke contract
  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  function handleRegister() {
    writeContract({
      ...jointVenturesConfig,
      functionName: "register",
      args: [name],
    });
  }

  if (!isConnected) {
    return <p className="text-center mt-20 text-muted-foreground">Connect your wallet first.</p>;
  }

  if (isMember) {
    return (
      <main className="flex justify-center items-center min-h-screen">
        <Card className="w-full max-w-sm">
          <CardContent className="p-6 text-center">
            <p className="text-green-500 font-bold text-lg">✓ Already registered</p>
            <p className="text-muted-foreground mt-1">Name: {memberName}</p>
          </CardContent>
        </Card>
      </main>
    );
  }

  return (
    <main className="flex justify-center items-center min-h-screen">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Register as Member</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">

          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Your name"
            className="w-full px-3 py-2 border rounded-md bg-background text-sm"
          />

          <Button
            onClick={handleRegister}
            disabled={!name || isPending || isConfirming}
            className="w-full"
          >
            {isPending ? "Waiting for wallet..." : isConfirming ? "Confirming..." : "Register"}
          </Button>

          {isSuccess && (
            <p className="text-green-500 text-sm text-center">Registered successfully!</p>
          )}
        </CardContent>
      </Card>
    </main>
  );
}
