'use client'

import { createContext } from 'react';

interface VmManagerContextType
{
  setSpinnerState: ( spinning: boolean, spinnerText?: string ) => void,
  showErrorModal: ( errorMessage: string ) => void
}

export const VmManagerContext = createContext<VmManagerContextType | null >(null);