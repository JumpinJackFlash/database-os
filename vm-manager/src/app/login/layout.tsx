'use server'

import LoginPage from './page'
import { getServiceData } from '@/utls/serverActions';

export default async function LoginLayout({}) 
{
  let response = await getServiceData();
  return(<LoginPage serviceTitle = {response.jsonData.serviceTitle} />);
}
