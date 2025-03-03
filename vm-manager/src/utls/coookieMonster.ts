'use server'
import { cookies } from 'next/headers'

const cookieName = 'sessionData';

export async function createSessionCookie(sessionId: string, accountType: string)
{
  const cookieStore = await cookies();
  cookieStore.set(cookieName, 
    JSON.stringify({sessionId: sessionId, accountType: accountType}),
    {
      httpOnly: true,
      secure: true,
      sameSite: 'lax'
    });
}

export async function deleteSessionCookie()
{
  const cookieStore = await cookies();
  cookieStore.delete(cookieName);
}

export async function eraseSessionCookie()
{
  const cookieStore = await cookies();
  cookieStore.set(cookieName, '');
}

export async function getSessionCookie()
{
  const cookieStore = await cookies();
  return cookieStore.get(cookieName);
}

