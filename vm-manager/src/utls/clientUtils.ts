'use client'

export function checkApiResponse(response: any, router: any)
{
  if (403 === response.httpStatus)
  {
    router('/login');
  }
}