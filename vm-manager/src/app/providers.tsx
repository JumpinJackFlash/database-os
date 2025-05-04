// app/providers.tsx
'use client'

import {HeroUIProvider} from '@heroui/react'
import {ToastProvider} from "@heroui/toast";

const placement = "top-right";

export function Providers({children}: { children: React.ReactNode }) {
  return (
    <HeroUIProvider>
      <ToastProvider placement={placement} />
      {children}
    </HeroUIProvider>
  )
}