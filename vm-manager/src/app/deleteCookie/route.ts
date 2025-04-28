import { deleteSessionCookie } from '@/utls/coookieMonster';
import { redirect } from 'next/navigation'

export async function GET(request: Request) 
{
  console.log('NextJS sucks....');
  await deleteSessionCookie();
  redirect('/login');
}