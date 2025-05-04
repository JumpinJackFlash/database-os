import { deleteSessionCookie } from '@/utils/coookieMonster';
import { redirect } from 'next/navigation'

export async function GET(request: Request) 
{
  await deleteSessionCookie();
  redirect('/login');
}