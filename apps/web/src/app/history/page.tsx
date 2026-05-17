"use client";

import { useAccount } from "wagmi";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useDepositHistory } from "@/hooks/graphql/useDepositHistory";

export default function HistoryPage() {
  const { address, isConnected } = useAccount();
  const { items, totalCount, isLoading } = useDepositHistory(address);

  if (!isConnected) {
    return <p className="text-center mt-20 text-muted-foreground">Connect your wallet first.</p>;
  }

  return (
    <main className="container max-w-3xl mx-auto py-12 px-4">
      <h1 className="text-3xl font-bold mb-2">My Deposit History</h1>
      <p className="text-muted-foreground mb-8">{totalCount} total deposits</p>

      {isLoading && <p className="text-muted-foreground">Loading...</p>}

      <div className="space-y-3">
        {items.map((item) => (
          <Card key={item.transactionHash}>
            <CardHeader className="pb-2">
              <CardTitle className="text-base font-medium">
                {Number(item.amount) / 1e6} {item.tokenSymbol}
              </CardTitle>
              <p className="text-xs text-muted-foreground">
                {new Date(Number(item.timestamp) * 1000).toLocaleString()}
              </p>
            </CardHeader>
            <CardContent>
              <a
                href={`https://celoscan.io/tx/${item.transactionHash}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-primary underline"
              >
                View on Celoscan
              </a>
            </CardContent>
          </Card>
        ))}

        {!isLoading && items.length === 0 && (
          <p className="text-muted-foreground text-center py-8">No deposits yet.</p>
        )}
      </div>
    </main>
  );
}
