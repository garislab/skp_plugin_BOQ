function gcFmt(n, digits) {
  if (n === undefined || n === null) return '-';
  digits = digits === undefined ? 2 : digits;
  return Number(n).toLocaleString('id-ID', { minimumFractionDigits: digits, maximumFractionDigits: digits });
}

function gcEscape(str) {
  const div = document.createElement('div');
  div.textContent = str === undefined || str === null ? '' : String(str);
  return div.innerHTML;
}
