import moment from 'moment';

export function formatTimestamp(timestamp: number, fullSpec: boolean)
{
  let formatSpec = 'L LT';
  if (fullSpec) formatSpec = 'LL LTS';

  if (null === timestamp) return null;
  
  return moment.unix(timestamp).utc().local().format(formatSpec);
}
  