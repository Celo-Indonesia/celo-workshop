"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useRegister } from "@/hooks/useJVWrite";
import { useIsMember } from "@/hooks/useJVRead";

export function RegisterForm() {
  const { address, isConnected } = useAccount();
  const { isMember, name: memberName } = useIsMember(address);
  const { register, isPending, isConfirming, isSuccess, error } = useRegister();
  const [name, setName] = useState("");

  if (!isConnected) return null;

  if (isMember) {
    return (
      <Card className="w-full max-w-md mx-auto">
        <CardHeader>
          <CardTitle className="text-lg">Member Status</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-green-500 font-medium">✓ Registered as <span className="font-bold">{memberName}</span></p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle className="text-lg">Register as Member</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <input
          type="text"
          placeholder="Your name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="w-full px-3 py-2 border rounded-md bg-background text-sm"
        />

        <Button
          onClick={() => register(name)}
          disabled={!name || isPending || isConfirming}
          className="w-full"
        >
          {isPending ? "Waiting for wallet..." : isConfirming ? "Confirming..." : "Register"}
        </Button>

        {isSuccess && <p className="text-green-500 text-sm">Registered successfully!</p>}
        {error && <p className="text-red-500 text-sm">{error.message}</p>}
      </CardContent>
    </Card>
  );
}
