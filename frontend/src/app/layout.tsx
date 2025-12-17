import type { Metadata } from "next";
import { IBM_Plex_Mono, Bebas_Neue } from "next/font/google";
import { Providers } from "@/components/Providers";
import "./globals.css";

const ibmPlexMono = IBM_Plex_Mono({
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700"],
  variable: "--font-mono",
});

const bebasNeue = Bebas_Neue({
  subsets: ["latin"],
  weight: ["400"],
  variable: "--font-display",
});

export const metadata: Metadata = {
  title: "Ferros Vault | ERC-4626 DeFi Yield Protocol",
  description: "Deposit USDC, earn yield, and withdraw anytime with Ferros Vault — an institutional-grade ERC-4626 tokenized yield vault built on Ethereum Sepolia with upgradeable proxy architecture.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
  openGraph: {
    title: "Ferros Vault | ERC-4626 DeFi Yield Protocol",
    description: "Deposit USDC, earn yield, and withdraw anytime with Ferros Vault — an institutional-grade ERC-4626 tokenized yield vault built on Ethereum Sepolia with upgradeable proxy architecture.",
    type: "website",
  },
  twitter: {
    card: "summary",
    title: "Ferros Vault | ERC-4626 DeFi Yield Protocol",
    description: "Deposit USDC, earn yield, and withdraw anytime with Ferros Vault — an institutional-grade ERC-4626 tokenized yield vault built on Ethereum Sepolia with upgradeable proxy architecture.",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${ibmPlexMono.variable} ${bebasNeue.variable}`}>
      <body className="antialiased">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
