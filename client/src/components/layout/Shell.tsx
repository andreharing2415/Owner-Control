import { Link, useLocation } from "wouter";
import { cn } from "@/lib/utils";
import { 
  Sidebar, 
  SidebarContent, 
  SidebarGroup, 
  SidebarGroupContent, 
  SidebarGroupLabel, 
  SidebarHeader, 
  SidebarMenu, 
  SidebarMenuItem, 
  SidebarMenuButton, 
  SidebarProvider,
  SidebarFooter,
  SidebarRail,
  SidebarTrigger
} from "@/components/ui/sidebar";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { NAV_ITEMS } from "@/lib/mock-data";
import { Button } from "@/components/ui/button";
import { Search } from "lucide-react";
import { MobileNav } from "@/components/layout/MobileNav";

export function Shell({ children }: { children: React.ReactNode }) {
  const [location] = useLocation();

  return (
    <SidebarProvider>
      <div className="flex min-h-screen w-full bg-background text-foreground font-sans">
        <AppSidebar location={location} />
        <main className="flex-1 flex flex-col min-w-0 overflow-hidden">
          <header className="sticky top-0 z-10 flex h-16 items-center justify-between border-b border-border bg-background/80 px-4 md:px-6 backdrop-blur-md shrink-0">
            <div className="flex items-center gap-4">
              <SidebarTrigger className="md:hidden" />
              <h1 className="text-lg md:text-xl font-display font-semibold tracking-tight truncate">
                {NAV_ITEMS.find(i => i.href === location)?.title || "OwnerControl"}
              </h1>
            </div>
            <div className="flex items-center gap-4">
              <Button variant="outline" size="sm" className="hidden md:flex gap-2 text-muted-foreground">
                <Search className="h-4 w-4" />
                <span className="text-xs">Buscar na obra...</span>
                <kbd className="pointer-events-none inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground opacity-100">
                  <span className="text-xs">⌘</span>K
                </kbd>
              </Button>
              <div className="h-8 w-8 rounded-full bg-gradient-to-tr from-primary to-purple-500 p-[1px]">
                <Avatar className="h-full w-full border-2 border-background">
                  <AvatarImage src="https://github.com/shadcn.png" />
                  <AvatarFallback>OC</AvatarFallback>
                </Avatar>
              </div>
            </div>
          </header>
          <div className="flex-1 overflow-auto p-4 pb-24 md:p-8 md:pb-8 animate-in fade-in duration-500">
            {children}
          </div>
        </main>
        <MobileNav />
      </div>
    </SidebarProvider>
  );
}

function AppSidebar({ location }: { location: string }) {
  return (
    <Sidebar className="border-r border-border bg-sidebar" collapsible="icon">
      <SidebarHeader className="h-16 flex items-center justify-center border-b border-sidebar-border px-4">
        <div className="flex items-center gap-2 font-display font-bold text-xl tracking-tighter w-full">
          <div className="h-8 w-8 rounded-lg bg-primary flex items-center justify-center text-primary-foreground">
            OC
          </div>
          <span className="group-data-[collapsible=icon]:hidden">OwnerControl</span>
        </div>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel className="text-xs font-medium text-muted-foreground/70 uppercase tracking-widest mt-4">
            Menu Principal
          </SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {NAV_ITEMS.map((item) => (
                <SidebarMenuItem key={item.title}>
                  <SidebarMenuButton 
                    asChild 
                    isActive={location === item.href}
                    tooltip={item.title}
                    className={cn(
                      "transition-all duration-200",
                      item.featured && "text-primary font-medium bg-primary/10 hover:bg-primary/20 hover:text-primary"
                    )}
                  >
                    <Link href={item.href}>
                      <item.icon className={cn("h-4 w-4", item.featured && "text-primary")} />
                      <span>{item.title}</span>
                    </Link>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>
      <SidebarFooter className="border-t border-sidebar-border p-4">
        <div className="rounded-lg bg-sidebar-accent p-3 text-xs text-sidebar-accent-foreground group-data-[collapsible=icon]:hidden">
          <div className="font-medium mb-1">Status da Obra</div>
          <div className="flex justify-between items-center text-muted-foreground">
            <span>Qualidade</span>
            <span className="text-green-500 font-bold">94%</span>
          </div>
          <div className="w-full bg-sidebar-border h-1 rounded-full mt-2 overflow-hidden">
            <div className="bg-green-500 h-full w-[94%]" />
          </div>
        </div>
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  );
}
