"use server"

import { cookies } from 'next/headers'

const cookieName = 'sessionData';

async function callDbTwig(apiCall: string, body?: any) 
{
  var cookieData = (await cookies()).get(cookieName);
  var bearerToken = null;
  if (undefined !== cookieData && '' !== cookieData.value)
  {
    const jData = JSON.parse(cookieData.value);
    bearerToken = jData.sessionId;
  }

  var requestOptions = {};
  
  if (undefined !== body)

    requestOptions = 
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + bearerToken },
      body: JSON.stringify(body)
    };
  else
    requestOptions = 
    {
      method: 'GET',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + bearerToken },
    };

  var httpResponse = await fetch(process.env.DB_TWIG_URL + '/' + apiCall, requestOptions);
  const jsonData = await httpResponse.json();
  let response =
  {
    jsonData: jsonData,
    ok: httpResponse.ok,
    httpStatus: httpResponse.status
  }

  if (!response.ok)
  {
    if ([401, 403].includes(response.httpStatus))
    {
      console.log('log user out....');
    }       
  }
  return response;
}

export async function createUserSession(identification: string, password: string)
{
  let bodyData = { identification, password };
  let response = await callDbTwig('icam/createUserSession', bodyData);
  if (response.ok)
  {
    console.log(response.jsonData);
    const cookieStore = await cookies()
    
    cookieStore.set(cookieName, 
      JSON.stringify({sessionId: response.jsonData.sessionId, accountType: response.jsonData.accountType}),
      {
        httpOnly: true,
        secure: true,
        sameSite: 'lax'
      });
  }
  return response;
}

export async function getListOfVirtualMachines()
{
  const response = await callDbTwig('dbos/getListOfVirtualMachines')
  return response;
}

export async function getServiceData()
{
  const response = await callDbTwig('dbos/getServiceData');
  if (response.ok)
  {
    process.env.JWT_SIGNING_KEY = response.jsonData.jwtSigningKey;
    process.env.JWT_EXPIRES_IN = response.jsonData.jwtExpiresIn;
  }
  return response;
}

export async function terminateUserSession()
{
  const response = await callDbTwig('icam/terminateUserSession');
  if (response.ok) (await cookies()).delete(cookieName);
  return response;
}