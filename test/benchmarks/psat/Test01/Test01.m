Bus.con = [ ...
% Bus no.    Vb       V_0     Theta_0  Area No. Region No.
   1        230.00  1.05000  0.00000    1           1;
   2        230.00  1.04000  0.00000    1           1;
   ]

SW.con = [ ...
% Bus no.     Sn      Vn      V_0    Theta_0   Qmax     Qmin    Vmax   Vmin
   1        100.00  230.00  1.0500  0.00000  1.50000 -1.50000  1.1    0.9   1.50000 1];

PV.con = [ ...
   2 100.00   230.00  0.50  1.04  2.50000 -2.50000 1.2 0.8 1];

Syn.con = [ 2 100 230.0 60 2 0 0 0.0 0.2995 0 5.89 0 0.0 0.00 0 0.0 0 6.296 2.0 0 0 1 1 0];

Line.con = [ ...
   1    2   100.00   230.00 60 0   0.0000  0.00  0.1  0.00000  1.00000  0.00000 0    0.000    0.000;
   1    2   100.00   230.00 60 0   0.0000  0.00  0.1  0.00000  1.00000  0.00000 0    0.000    0.000];

Areas.con = [1    1 100.00  0.00000  9.99990];

Varname.bus = {'Bus 1'; 'Bus 2'};

Breaker.con = [ 1  1  100  138  60  1  1  200];