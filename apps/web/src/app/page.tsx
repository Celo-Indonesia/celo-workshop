import { Zap } from "lucide-react";
import { UserBalance } from "@/components/user-balance";
import { JVStats } from "@/components/joint-ventures/JVStats";
import { RegisterForm } from "@/components/joint-ventures/RegisterForm";
import { DepositForm } from "@/components/joint-ventures/DepositForm";

export default function Home() {
  return (
    <main className="flex-1">
      <section className="relative py-20 lg:py-32">
        <div className="container px-4 mx-auto max-w-7xl">
          <div className="text-center max-w-4xl mx-auto">
            <div className="inline-flex items-center gap-2 px-3 py-1 mb-8 text-sm font-medium bg-primary/10 text-primary rounded-full border border-primary/20">
              <Zap className="h-4 w-4" />
              Built on Celo
            </div>

            <h1 className="text-4xl md:text-6xl lg:text-7xl font-bold tracking-tight mb-6">
              Joint Ventures{" "}
              <span className="text-primary">Workshop</span>
            </h1>

            <p className="text-lg md:text-xl text-muted-foreground mb-12 max-w-2xl mx-auto leading-relaxed">
              Pool funds together on Celo. Register as a member, deposit USDC or USDT, and track progress toward the target.
            </p>

            <div className="space-y-8">
              <JVStats />
              <UserBalance />
              <RegisterForm />
              <DepositForm />
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
