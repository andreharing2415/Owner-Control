import { Link, useLocation } from "wouter";
import { cn } from "@/lib/utils";
import { Calendar, DollarSign, FileText, HardHat } from "lucide-react";

const MOBILE_NAV_ITEMS = [
  { title: "Ver Etapas", icon: Calendar, href: "/app/timeline" },
  { title: "Financeiro", icon: DollarSign, href: "/app/financial" },
  { title: "Documentos", icon: FileText, href: "/app/documents" },
  { title: "Prestadores", icon: HardHat, href: "/app/providers" },
];

export function MobileNav() {
  const [location] = useLocation();

  return (
    <nav className="fixed inset-x-0 bottom-0 z-20 border-t border-border bg-background/90 backdrop-blur-md md:hidden">
      <div className="mx-auto flex max-w-7xl items-center justify-between px-3 pb-[env(safe-area-inset-bottom)] pt-2">
        {MOBILE_NAV_ITEMS.map((item) => {
          const isActive = location === item.href;
          return (
            <Link key={item.title} href={item.href} className="flex flex-1">
              <div
                className={cn(
                  "flex w-full flex-col items-center justify-center gap-1 rounded-md px-2 py-2 text-xs transition-colors",
                  isActive
                    ? "text-primary"
                    : "text-muted-foreground hover:text-foreground"
                )}
              >
                <item.icon className="h-5 w-5" />
                <span className="line-clamp-1">{item.title}</span>
              </div>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
