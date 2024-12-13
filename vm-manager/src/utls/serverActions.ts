"use server"

async function callDbTwig(apiCall: string, body?: any) 
{
  var authData;
  let bearerToken = null;
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

export async function getListOfVirtualMachines()
{
  const response = await callDbTwig('dbos/getListOfVirtualMachines')
  return response;
}