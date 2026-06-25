type
  ttime = record
    minut: integer;//время в минутах от полуночи
  end;
  tdate = record
    dd, mm, yy: integer;
  end;
  rec = record
   line: string;//исхрдная строка
   n1, n2: int64;//номера телефонов
   tip: string;//тип звонка
   dat: tdate;//дата
   t1, t2: ttime;//время начала и конца
   conflict: boolean;
 end;
//e=1 - incorrect e=2 - skip e=3 - abnormal e=4 - conflict e=5 - duplicate
const
  n = 1000;

type
  arrtype = array[1..n] of rec;

var
  arr: arrtype;
  k: integer;
  f, fskip, fincor, fabn, fdup, fconf, fout: text;

procedure month_num(s: string; var m: integer);//название месяца в номер
begin
  s := lowercase(s);
  if (s = 'jan') or (s = 'january') then m := 1
  else if (s = 'feb') or (s = 'february') then m := 2
  else if (s = 'mar') or (s = 'march') then m := 3
  else if (s = 'apr') or (s = 'april') then m := 4
  else if s = 'may' then m := 5
  else if (s = 'jun') or (s = 'june') then m := 6
  else if (s = 'jul') or (s = 'july') then m := 7
  else if (s = 'aug') or (s = 'august') then m := 8
  else if (s = 'sep') or (s = 'september') then m := 9
  else if (s = 'oct') or (s = 'october') then m := 10
  else if (s = 'nov') or (s = 'november') then m := 11
  else if (s = 'dec') or (s = 'december') then m := 12
  else m := 0;
end;

procedure check_phone(s: string; var x: int64; var e: integer);//проверка телефона
var
  n: integer;
begin
  if e = 0 then
  begin
    if (length(s) <> 11) or (s[1] <> '7') then e := 1
    else
    begin
      val(s,x,n);
      if n <> 0 then e := 1;
    end;
  end;
end;

procedure check_type(s: string; var tip: string; var e: integer);//чекаем тайп
begin
  if e = 0 then
  begin
    if (s <> 'YHR') and (s <> 'YNR') and (s <> 'NHR') and (s <> 'NNR') then e := 1
    else
      tip := s;
  end;
end;

procedure check_date(dd, mm, yy: integer; var ok: boolean);//проверка даты
var d: integer;
begin
  ok := true;
  if (yy < 2000) or (yy > 2025) then ok := false;
  if ok and ((mm < 1) or (mm > 12)) then ok := false;
  if ok then begin
    case mm of
      1,3,5,7,8,10,12: d := 31;
      4,6,9,11: d := 30;
      2: if (yy mod 4 = 0) then d := 29 else d := 28;
    end;
    if (dd < 1) or (dd > d) then ok := false;
  end;
end;

procedure parse_time(s, mer: string; var t: ttime; var ok: boolean);//пр время в минуты
var p, h, m, code: integer;
begin
  ok := true;
  p := pos(':', s);
  if p = 0 then ok := false;
  if ok then val(copy(s, 1, p-1), h, code);
  if ok then if code <> 0 then ok := false;
  if ok then val(copy(s, p+1, length(s)-p), m, code);
  if ok then if code <> 0 then ok := false;
  mer := lowercase(mer);
  if ok then begin
    if (h < 1) or (h > 12) then ok := false;
    if (m < 0) or (m > 59) then ok := false;
  end;
  if ok then begin
    if mer = 'am' then begin if h = 12 then h := 0; end
    else if mer = 'pm' then begin if h <> 12 then h := h + 12; end
    else ok := false;
  end;
  if ok then t.minut := h * 60 + m;
end;

procedure split(s: string; var p1,p2,p3,p4,p5,p6,p7,p8,p9,p10: string);//для разбивки строки
var a: array[1..10] of string; i,j,c: integer;
begin
  for i := 1 to 10 do a[i] := '';
  i := 1; c := 0;
  while i <= length(s) do begin
    while (i <= length(s)) and (s[i] = ' ') do i := i + 1;
    if i <= length(s) then begin
      c := c + 1;
      j := i;
      while (j <= length(s)) and (s[j] <> ' ') do j := j + 1;
      a[c] := copy(s, i, j-i);
      i := j;
    end;
  end;
  p1 := a[1]; p2 := a[2]; p3 := a[3]; p4 := a[4]; p5 := a[5];
  p6 := a[6]; p7 := a[7]; p8 := a[8]; p9 := a[9]; p10 := a[10];
end;

procedure check_two_spaces(s: string; var e: integer);//2 пробела = скип
var i: integer;
begin
  e := 0;
  for i := 1 to length(s)-1 do
    if (s[i] = ' ') and (s[i+1] = ' ') then 
      e := 2;
end;

function duration(x: rec): integer;//длительность звонка
var res: integer;
begin
  res := x.t2.minut - x.t1.minut;
  if res < 0 then res := res + 1440;
  duration := res;
end;

function daytime(t: integer): integer;//время суток для сортировки: сортировка сначала утро, день, вечер, ночь
var h: integer;
begin
  h := t div 60;
  if (h >= 6) and (h <= 11) then daytime := 1
  else if (h >= 12) and (h <= 17) then daytime := 2
  else if (h >= 18) and (h <= 23) then daytime := 3
  else daytime := 4;
end;

function swap(a, b: rec): boolean;//правила сортировки по времени суток -> по длительности -> по времени начала
begin
  swap := false;
  if daytime(a.t1.minut) > daytime(b.t1.minut) then swap := true
  else if daytime(a.t1.minut) = daytime(b.t1.minut) then begin
    if duration(a) > duration(b) then swap := true
    else if (duration(a) = duration(b)) and (a.t1.minut > b.t1.minut) then swap := true;
  end;
end;

procedure sort(var a: arrtype; k: integer);//ну сорт
var i,j: integer; t: rec;
begin
  for i := 1 to k-1 do
    for j := 1 to k-i do
      if swap(a[j], a[j+1]) then begin
        t := a[j];
        a[j] := a[j+1];
        a[j+1] := t;
      end;
end;

procedure check_full_date(p4,p5,p6: string; var d: tdate; var e: integer);//чек дату
var
  code,m: integer;
  ok: boolean;
begin
  if e = 0 then
  begin
    val(p4,d.dd,code);
    if code <> 0 then e := 3;
  end;
  if e = 0 then
  begin
    val(p6,d.yy,code);
    if code <> 0 then e := 3;
  end;
  if e = 0 then
  begin
    month_num(p5,m);
    if m = 0 then e := 3
    else
      d.mm := m;
  end;
  if e = 0 then
  begin
    check_date(d.dd,d.mm,d.yy,ok);
    if not ok then e := 3;
  end;
end;

procedure check_full_time(vremya,mer: string; var t: ttime; var e: integer);//чек время
var
  ok: boolean;
begin
  if e = 0 then
  begin
    parse_time(vremya,mer,t,ok);
    if not ok then e := 3;
  end;
end;

procedure check_duplicate(r: rec; var e: integer);//дубликаты
var
  i: integer;
begin
  if e = 0 then
    for i := 1 to k do
      if r.line = arr[i].line then e := 5;
end;

function time_overlap(t1_start, t1_end, t2_start, t2_end: integer): boolean;//функция на пересечение времени
begin
  time_overlap := (t1_start <= t2_end) and (t2_start <= t1_end);
end;

function dates_equal(d1, d2: tdate): boolean;//функция равных дат на конфликты
begin
  dates_equal := (d1.dd = d2.dd) and (d1.mm = d2.mm) and (d1.yy = d2.yy);
end;

procedure check_all_conflicts(r: rec; var e: integer);
var
  i: integer;
begin
  if e = 0 then
  begin
    if r.t2.minut <= r.t1.minut then
      e := 4
    else
    begin
      i := 1;
      while (i <= k) and (e = 0) do
      begin
        if dates_equal(r.dat, arr[i].dat) then
        begin
          if time_overlap(r.t1.minut, r.t2.minut, arr[i].t1.minut, arr[i].t2.minut) then
          begin
            if ((r.n1 = arr[i].n1) and (r.n2 <> arr[i].n2)) or ((r.n2 = arr[i].n2) and (r.n1 <> arr[i].n1)) then
            begin
              arr[i].conflict := true;
              e := 4;
            end;
          end;
        end;
        i := i + 1;
      end;
    end;
  end;
end;

function month_name(m: integer): string;//формат для вывода
begin
  case m of
    1: month_name := 'Jan';
    2: month_name := 'Feb';
    3: month_name := 'Mar';
    4: month_name := 'Apr';
    5: month_name := 'May';
    6: month_name := 'Jun';
    7: month_name := 'Jul';
    8: month_name := 'Aug';
    9: month_name := 'Sep';
    10: month_name := 'Oct';
    11: month_name := 'Nov';
    12: month_name := 'Dec';
  end;
end;

function format_num(n: integer): string;//ведущий ноль
var s: string;
begin
  str(n, s);
  if length(s) = 1 then s := '0' + s;
  format_num := s;
end;

procedure read_phone;
var s: string; p1,p2,p3,p4,p5,p6,p7,p8,p9,p10: string;
    r: rec; i,e: integer;
    h1,m1,h2,m2: integer;
begin
  k := 0;
  while not eof(f) do begin
    readln(f, s);
    check_two_spaces(s, e);
    if e = 2 then
      writeln(fskip, s)
    else begin
      e := 0;
      split(s, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10);
      r.line := s;
      check_phone(p1,r.n1,e);
      check_phone(p2,r.n2,e);
      check_type(p3,r.tip,e);
      check_full_date(p4,p5,p6,r.dat,e);
      check_full_time(p7,p8,r.t1,e);
      check_full_time(p9,p10,r.t2,e);
      if (e = 0) and (r.t2.minut <= r.t1.minut) then e := 4;
      check_duplicate(r,e);
      check_all_conflicts(r, e);
      if e = 1 then
        writeln(fincor, s)
      else if e = 3 then
        writeln(fabn, s)
      else if e = 5 then
        writeln(fdup, s)
      else
      begin
        k := k + 1;
        arr[k] := r;
        if e = 4 then
          arr[k].conflict := true
        else
          arr[k].conflict := false;
      end;
    end;
  end;
  sort(arr, k);
  for i := 1 to k do
  begin
    if arr[i].conflict then
      writeln(fconf, arr[i].line)
    else
    begin
      h1 := arr[i].t1.minut div 60;
      m1 := arr[i].t1.minut mod 60;
      h2 := arr[i].t2.minut div 60;
      m2 := arr[i].t2.minut mod 60;
      writeln(fout, '|',  arr[i].n1, '|', arr[i].n2, '|', arr[i].tip, '|', format_num(arr[i].dat.dd), '.', month_name(arr[i].dat.mm), '.', arr[i].dat.yy, '|', format_num(h1), ':', format_num(m1), '|', format_num(h2), ':', format_num(m2), '|');
    end;
  end;
end;

begin
  assign(f, 'input.txt');
  assign(fskip, 'skip.txt');
  assign(fincor, 'incorrect.txt');
  assign(fabn, 'abnormal.txt');
  assign(fdup, 'duplicate.txt');
  assign(fconf, 'conflict.txt');
  assign(fout, 'output.txt');
  reset(f);
  rewrite(fskip);
  rewrite(fincor);
  rewrite(fabn);
  rewrite(fdup);
  rewrite(fconf);
  rewrite(fout);
  read_phone;
  close(f);
  close(fskip);
  close(fincor);
  close(fabn);
  close(fdup);
  close(fconf);
  close(fout);
end.