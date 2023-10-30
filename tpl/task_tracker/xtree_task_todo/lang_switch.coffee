eng = 'qwertyuiop[]asdfghjkl;\'zxcvbnm,.QWERTYUIOPХ}ASDFGHJKL:"ZXCVBNM<>`~sS]}\'"'
rus = 'йцукенгшщзхъфывапролджэячсмитьбюЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮёЁіІїЇєЄ'
window.lang_switch = (text) ->
  rus_point = 0
  eng_point = 0
  for v in text
    eng_point += eng.indexOf(v)!= -1
    rus_point += rus.indexOf(v)!= -1
  if rus_point > eng_point
    from = rus
    to   = eng
  else
    from = eng
    to   = rus
  ret = ''
  for v in text
    idx = from.indexOf v
    ret += if idx == -1 then v else to[idx]
  ret