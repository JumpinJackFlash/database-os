import type { NextRequest } from 'next/server'
import { NextResponse } from 'next/server'
import { cookies } from 'next/headers';

export async function middleware(request: NextRequest) 
{
/*
    const cAuthPaths = ['/dashboard', '/recentlogs']
    if (cAuthPaths.includes(request.nextUrl.pathname) && undefined === request.cookies.get('auth.msr'))
    {
      console.log('middleware redirect...');
      return NextResponse.redirect(new URL('/login', request.url));       
    } 
*/

  if ('/favicon.ico' === request.nextUrl.pathname) return;
  const cookieStore = await cookies();
  const sessionCookie = cookieStore.get('sessionData');
  var sessionId = null;
  if (undefined !== sessionCookie)
  {
    const jData = JSON.parse(sessionCookie.value);
    sessionId = jData.sessionId;
  }
  console.log('Path: ' + request.nextUrl.pathname + ' - sessionId: ' + sessionId);
  if ('/' === request.nextUrl.pathname && null === request.headers.get('Authorization')) return NextResponse.redirect(new URL('/login', request.url));
  if ('/virtualMachines' === request.nextUrl.pathname && null === sessionId)  return NextResponse.redirect(new URL('/login', request.url));
}

// Routes Middleware should not run on
export const config = 
{
  matcher: ['/((?!api|_next/static|_next/image|.*\\.png$).*)'],
}