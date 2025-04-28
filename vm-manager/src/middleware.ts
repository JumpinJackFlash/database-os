import type { NextRequest } from 'next/server'
import { NextResponse } from 'next/server'
import { getSessionCookie } from './utils/coookieMonster';

export async function middleware(request: NextRequest) 
{
    console.log(request.nextUrl.pathname);
    if ('/favicon.ico' === request.nextUrl.pathname) return;
    const cAuthPaths = ['/virtualMachines'];
    const cookieData = await getSessionCookie();
    if (cAuthPaths.includes(request.nextUrl.pathname) && undefined === cookieData)
    {
      console.log('middleware redirect...');
      return NextResponse.redirect(new URL('/login', request.url));       
    }

    if ('/' === request.nextUrl.pathname && undefined === cookieData) return NextResponse.redirect(new URL('/login', request.url));
    if ('/' === request.nextUrl.pathname && undefined !== cookieData) return NextResponse.redirect(new URL('/virtualMachines', request.url));

/*  const sessionCookie = await getSessionCookie();
  var sessionId = null;
  if (undefined !== sessionCookie)
  {
    const jData = JSON.parse(sessionCookie.value);
    sessionId = jData.sessionId;
  }
  console.log('Path: ' + request.nextUrl.pathname + ' - sessionId: ' + sessionId);
  if ('/' === request.nextUrl.pathname && null === request.headers.get('Authorization')) return NextResponse.redirect(new URL('/login', request.url));
  if ('/virtualMachines' === request.nextUrl.pathname && null === sessionId)  return NextResponse.redirect(new URL('/login', request.url)); */
}

// Routes Middleware should not run on
export const config = 
{
  matcher: ['/((?!api|_next/static|_next/image|.*\\.png$).*)'],
}