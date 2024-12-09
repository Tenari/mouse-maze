// place files you want to import through the `$lib` alias in this folder.

export const padHex = (str) => {
  if (str.length < 6) {
    return padHex('0'+str);
  } else {
    return str.substr(0,6);
  }
};
