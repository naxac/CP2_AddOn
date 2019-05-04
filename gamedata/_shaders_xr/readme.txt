###########################################################
S.T.A.L.K.E.R. shaders.xr compiler/decompiler

=========»спользование============

ƒекомпил€ци€:	sxrcdc.pl -d <input_file> [-o <outdir> -m <ltx|bin> -l <logfile>]

-d <input_file> - входной файл (shaders.xr)
-o <outdir> - папка, куда сохран€ть шейдеры

 омпил€ци€:	sxrcdc.pl -c <input_dir> [-o <outfile> -mode <ltx|bin> -l <logfile>]

-c <input_dir> - папка, где лежат шейдеры
-o <outfile> - выходной файл

ќбщие опции:
-m <ltx|bin> - режим декомпил€ции. bin -разбивать на бинарные файлы, ltx - полна€ декомпил€ци€.
-l <logfile> - файл лога

»стори€ версий:
[0.2]:
	полный рефакторинг кода
[0.1]:
	начальный релиз