%%%%%%%%%
%
% Basic style file for Hunyuan open-access papers and unpublished papers.
%
% This class allows for several options depending on the preferences of the authors.
% Use it in the following way, with the full set of option possible:
% \documentclass[11pt, a4paper, twocolumn, logo, address, copyright, nonumbering,
% internal]{hunyuan_arxiv}
%
% Options:
%    - 11pt: Sets the normal font size of the text. Can be only 10, 11, 12pt.
%    - a4paper: Paper size. Usually would not adjust.
%    - twocolumn: Makes the paper into two column mode; single column by default.
%    - logo: Adds the Hunyuan logo to the top left. No logo included if left out.
%    - address: Add a postal address for correspondence to the bottom footer.
%    - copyright: Add a copyright statement to the first page of the paper in the left footnote
%    - nonumbering: Uses unnumbered sections.
%    - internal: for internal only docs that should not be shared externally.
%           Can only use techreportnumber with this option.
%
% Date of Paper
%   The report is by default given the curren date in the top right. If you want to fix the
%   date: add the date to your preamble with your own date as follows:
%   \renewcommand{\today}{1 January 2000}
%
% Confidentiality
%   Change the confidentiality statement for internal docs by adding this in the preable
%   \renewcommand{\internalonly}{Confidential.}
%
% ----------------
% Licence: This template is released under the Creative Commons licence
% Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
%
%
% Known issues:
%   - Package todonotes does not work in the abstract
%
% Version history:
% v0.4, Sept 2023 - Update to Hunyuan unit
% v0.31, May 2019 - Allow corresponding authors without internal option
% v0.3, March 2019 - Math font consistency, better handling of optional arguments
% v0.2, January 2019 - Consistency of fonts, margins, additional notes
% v0.1, December 2018 - Initial version for testing
%
% Ongoing Review
%    We review and improve this regularly.
%    Send comments to shakir@
%
%  Adapted for Hunyuan papers.
%
% %%%%%%%%%%%%%%%

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{arXiv-2605.19597v1/hunyuan_arxiv} % no versioning; versioning does not work well with arxiv.

%%======== Pckage options and base class ========
\RequirePackage{xifthen}
\newboolean{nonumbering}
\newboolean{logo}
\newboolean{address}
\newboolean{copyright}
\newboolean{internal}
\DeclareOption{nonumbering}{\setboolean{nonumbering}{true}}
\DeclareOption{logo}{\setboolean{logo}{true}}
\DeclareOption{address}{\setboolean{address}{true}}
\DeclareOption{copyright}{\setboolean{copyright}{true}}
\DeclareOption{internal}{\setboolean{internal}{true}}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{extarticle}}
\ProcessOptions
\LoadClass{extarticle}

%%======== Packages Required ========
% Fonts and language
% \AtEndOfClass{\RequirePackage[tracking=smallcaps]{microtype}}
\RequirePackage[utf8]{inputenc}
\RequirePackage[english]{babel}
\RequirePackage{amsthm, amsmath, amsfonts, amssymb}
\RequirePackage{cmap}
\RequirePackage[T1]{fontenc}
\RequirePackage{url}
\RequirePackage[colorlinks=true, allcolors=blue]{hyperref}
\RequirePackage{pifont}
\RequirePackage[dvipsnames]{xcolor}
\definecolor{gblue9}{RGB}{23, 78, 166}
\definecolor{black50}{gray}{0.5}
\RequirePackage{textcomp} % For copyright symbol styling
\RequirePackage[overload]{textcase}
%\RequirePackage{balance}
%% *Graphics, tables and other formatting
\RequirePackage{graphicx}
\RequirePackage{colortbl}
\RequirePackage{booktabs}
\RequirePackage{changepage}
\RequirePackage{enumitem} % For reducing bullet list item separation
\RequirePackage{tabularx}
\RequirePackage{datetime}
% Headers and footers
\RequirePackage{fancyhdr}  % custom headers/footers
\RequirePackage{lastpage}  % Number of pages in the document
% Lists and their spacing
\RequirePackage{enumitem}
\setlist[itemize]{noitemsep}
\setlist[enumerate]{noitemsep}
% Title, Abstract, Bibliography
\RequirePackage[explicit]{titlesec}
\RequirePackage{bibentry}
\RequirePackage{mdframed}
\RequirePackage{caption}
\RequirePackage{needspace}

%%======== Can use any of these fonts ========
%\RequirePackage{charter}
%\RequirePackage[scaled]{helvet}
%\RequirePackage{bookman}
%\RequirePackage{times}
%\RequirePackage[default]{opensans} %fosfamily
%\usepackage{antpolt}
% Math fonts
%\RequirePackage{mathpazo} % Palatino
%\usepackage{euler} % for math fints

% Prefer the original template fonts, but fall back on TeX Live Basic fonts.
\IfFileExists{XCharter.sty}{%
  \RequirePackage{XCharter}%
  \IfFileExists{newtxmath.sty}{%
    \RequirePackage[xcharter,bigdelims,vvarbb]{newtxmath}%
  }{%
    \RequirePackage{mathptmx}%
  }%
}{%
  \RequirePackage{times}%
  \RequirePackage{mathptmx}%
}

% Use the typewriter font from lmodern, scaled up to match Charter's xheight.
% You may wish to add the "p" option to use the proportional font instead of
% the monospaced one, which might look nicer in cases where you do not need
% aligned columns
\IfFileExists{zlmtt.sty}{%
  \RequirePackage[scaled=1.1]{zlmtt}%
}{%
  \IfFileExists{inconsolata.sty}{\RequirePackage{inconsolata}}{}%
}

%%======== Margins and column spacing ========
\RequirePackage[left=2.2cm,%
right=2.2cm,%
top=3cm,%
bottom=3cm,%
headheight=40pt,%
headsep=20pt,%
%showframe, % for testing
a4paper]{geometry}%
\setlength{\columnsep}{15pt} % Distance between the two columns of text
%\setlength{\parindent}{0pt}
\setlength{\parskip}{0.5\baselineskip}

%% *Custom font sizes and styles
\newcommand{\watermarkfont}{\color{black50}\normalfont\fontsize{10}{12}\selectfont}
\newcommand{\headerfont}{\normalfont\sffamily\fontsize{8}{10}\selectfont}
\newcommand{\titlefont}{\color{black}\normalfont\bfseries\fontsize{16}{23}\selectfont}
\newcommand{\datesfont}{\normalfont\sffamily\itshape\fontsize{8}{10}\selectfont}
\newcommand\urlheaderfont{\color{blue}\fontsize{8}{10}\selectfont}
\newcommand{\absfont}{\bfseries\linespread{1.2}\fontsize{10}{12}\selectfont}
\newcommand{\keywordstitlefont}{\bfseries\linespread{1.2}\fontsize{8}{10}\selectfont}
\newcommand{\keywordsfont}{\itshape\linespread{1.2}\fontsize{11}{12}\selectfont}
\newcommand{\copyrightfont}{\normalfont\fontsize{7}{9}\selectfont}
\newcommand{\footerfont}{\color{black}\normalfont\fontsize{8}{10}\selectfont}
\newcommand{\subjectfont}{\color{white}\bfseries\fontsize{10}{12}\selectfont}
\newcommand{\headingfont}{\color{black}\bfseries\fontsize{13}{14}\selectfont}

\newcommand{\keywords}[1]{\def\@keywords{#1}}
\newtoks\correspondingauthor
\newtoks\contribution
\newtoks\paperurl
\newtoks\reportnumber

% Dates and Times for footer
%\newdateformat{monthyeardate}{\THEDAY{ }\monthname[\THEMONTH] \THEYEAR}
% ISO-8601 date format
\newdateformat{monthyeardate}{\THEYEAR-\THEMONTH-\THEDAY}

\setcounter{secnumdepth}{3}
\ifthenelse{\boolean{nonumbering}}{\setcounter{secnumdepth}{0}}{}

%%========  Author and affiliation ========
\RequirePackage{authblk}
\setcounter{Maxaffil}{0}
\setlength{\affilsep}{0.2em}
\renewcommand\Authfont{\normalfont\bfseries} % 不再强制缩小字号
\renewcommand\Affilfont{\normalfont}
% \renewcommand\Authfont{\normalfont\bfseries\fontsize{9}{13}\selectfont}
% \renewcommand\Affilfont{\normalfont\fontsize{8}{10}\selectfont}
\makeatletter
\renewcommand\AB@affilsepx{, \protect\Affilfont}
\makeatother
\renewcommand\Authands{ and }

\newcommand{\internalonly}{Confidential -- Hunyuan Team, Tencent, do not share or forward externally.}
\newcommand{\copyrightext}{\footerfont \textcopyright\, \the\year{} Google. All rights
reserved}


%%======== Header and Footer Content ========
%
% Header and Footer for the first page
\pagestyle{fancy}   % Enables the custom headers/footers
\fancypagestyle{firststyle}{
	\fancyhead[L]{
		\ifthenelse{\boolean{logo}}{
			\includegraphics[width=120pt]{hunyuan_arxiv_assets/logo.png}
	 }{}
}

\fancyhead[R]{
	\ifdefined\paperurl
	\if\relax\the\paperurl\relax \else
		\href{\the\paperurl}{\urlheaderfont \itshape \the\paperurl}\\ \fi
	\else \fi
	{\footerfont\itshape\monthyeardate\today}
}
\fancyhead[C]{}
%
\fancyfoot[L]{
	\ifdefined\correspondingauthor
	\if\relax\the\correspondingauthor\relax
	\else \footerfont\itshape  {Corresponding author(s): \the\correspondingauthor \\} \fi
	\else \fi
    \ifthenelse{\boolean{internal}}{\footerfont \internalonly \\}{\footerfont\bfseries\relax}
	\ifthenelse{\boolean{address}}{
		\itshape\footerfont Hunyuan Team, Tencent \\}{}
	% \ifthenelse{\boolean{copyright}}{\copyrightext}{}
	\ifdefined\contribution
	\if\relax\the\contribution\relax
	\else \footerfont \the\contribution \fi
	\else \fi
}
\fancyfoot[R]{
	\ifthenelse{\boolean{internal}}{
	\ifdefined\reportnumber
	\if\relax\the\reportnumber\relax
	\else \footerfont\itshape  {\footerfont \bfseries Hunyuan Technical Report \the\reportnumber} \fi
	\else \fi
	}{\footerfont\bfseries\relax}
}
\fancyfoot[C]{
	\relax
}
}

% Header and Footer for pages from 2 onwards
\fancyhead[L,R]{}
\makeatletter
\fancyhead[C]{\footerfont \@title}
\makeatother
\fancyfoot[C]{}
\fancyfoot[L]{
	\ifthenelse{\boolean{internal}}{\footerfont \internalonly\newline
		\ifdefined\reportnumber
		\if\relax\the\reportnumber\relax
		\else \footerfont {GDM-TR \the\reportnumber} \fi
		\else \fi}{\footerfont\bfseries\relax}
}
\fancyfoot[R]{\footerfont \thepage}

% Header and footer rules (coloured).
\renewcommand{\headrulewidth}{1pt}
\renewcommand{\footrulewidth}{1pt}
\let\DefaultHeadRule\headrule
\let\DefaultFootRule\footrule
\renewcommand{\headrule}{\color{gray}\DefaultHeadRule}
\renewcommand{\footrule}{\textcolor{gray}{\DefaultFootRule}}

\renewenvironment{abstract}
{\par\noindent\\  \ignorespaces \bfseries}
{\par\bigskip}

%%========  Bibliography using bibtex ========
\addto{\captionsenglish}{\renewcommand{\refname}{References}}
\newcommand{\citeas}[1]{\Needspace*{8\baselineskip}\noindent\bibentry{#1}}
% Uncomment the next line if you want the  numbered refs to be "1." instead of "[1]".
%\makeatletter \renewcommand\@biblabel[1]{#1.} \makeatother

%%======== Abstract and section formatting ========
% \def\xabstract{abstract}
% \long\def\abstract#1\end#2{\def\two{#2}\ifx\two\xabstract
% 	\long\gdef\theabstract{\ignorespaces#1}
% 	\def\go{\end{abstract}}\else
% \typeout{^^J^^J PLEASE DO NOT USE ANY \string\begin\space \string\end^^J
% 	COMMANDS WITHIN ABSTRACT^^J^^J}#1\end{#2}
% \gdef\theabstract{\vskip12pt BADLY FORMED ABSTRACT: PLEASE DO
% NOT USE {\tt\string\begin...\string\end} COMMANDS WITHIN
% THE ABSTRACT\vskip12pt}\let\go\relax\fi
% \go}
% replace your current definition by the coloured version
\def\xabstract{abstract}
\long\def\abstract#1\end#2{%
  \def\two{#2}%
  \ifx\two\xabstract
    % 把内容封装进圆角 tcolorbox
    \long\gdef\theabstract{%
      \begin{tcolorbox}[
          colback=gblue9!5,     % 背景色
          colframe=gblue9!5,    % 边框跟背景同色（等于隐藏边框）
          boxrule=0pt,          % 无边框线
          arc=6pt,              % 圆角半径，改成 2pt~6pt 都可以
          left=8pt,right=8pt,   % 内边距
          top=6pt,bottom=6pt,
          breakable             % 允许跨页（可选）
      ]
        \ignorespaces #1
      \end{tcolorbox}%
    }%
    \def\go{\end{abstract}}%
  \else
    \typeout{^^J^^J PLEASE DO NOT USE ANY \string\begin\space \string\end^^J
      COMMANDS WITHIN ABSTRACT^^J^^J}%
    #1\end{#2}%
    \gdef\theabstract{%
      \vskip12pt
      BADLY FORMED ABSTRACT: PLEASE DO
      NOT USE {\tt\string\begin...\string\end} COMMANDS WITHIN
      THE ABSTRACT\vskip12pt}%
    \let\go\relax
  \fi
  \go
}


% Define an environment with abstract content and styling
\makeatletter
\newcommand{\abscontent}{
	\noindent
	\parbox{\dimexpr\linewidth}{\absfont \theabstract}
	\@ifundefined{@keywords}{}{
		\vskip1em \noindent \keywordsfont  Keywords: \@keywords}
}

\if@twocolumn%
\renewcommand{\maketitle}{
	\twocolumn[
	\begin{adjustwidth}{0pt}{24pt}
		\begin{center}
			{
				{ \centering \titlefont
				\@title\par}%
				\vskip11pt
				{\centering \@author\par}
				\vskip20pt%
			}%
		\end{center}
	\end{adjustwidth}

		\abscontent
	\vskip20pt%
	]
	\thispagestyle{firststyle}
}%
\else% \@twocolumnfalse
\renewcommand{\maketitle}{\bgroup\setlength{\parindent}{0pt}
	\begin{adjustwidth}{0pt}{16pt}
		\begin{center}
			{
				{\centering \titlefont \@title\par}%
				\vskip5pt
				{\centering \@author\par}
				\vskip5pt%
			}%
		\end{center}
	\end{adjustwidth}
	\egroup
	{%
		{\abscontent}
	}%
	\thispagestyle{firststyle}
}%
\fi
\makeatother

\titleformat{\section}
{\large\bfseries\headingfont}
{\thesection.}
{0.5em}
%{\MakeUppercase{#1}}[]
{#1}
[]
\titleformat{name=\section,numberless}
{\large\bfseries\headingfont}
{}
{0em}
%{\MakeUppercase{#1}}[]
{#1}
[]
\titleformat{\subsection}
{\bfseries}
{\thesubsection.}
{0.5em}
{#1}
[]
\titleformat{\subsubsection}% [runin] If want to have inline for the subsubsect
{\bfseries\itshape}
{\thesubsubsection.}
{0.5em}
{#1}
[]
\titleformat{\paragraph}[runin]
  {\normalfont\bfseries}
  {}
  {0pt}
  {#1 \hspace{0.5em}}
[]


\titlespacing*{\section}{0pc}{3ex plus4pt minus3pt}{5pt}
%\titlespacing*{\section}{0pc}{1ex }{\baselineskip}
\titlespacing*{\subsection}{0pc}{2.5ex plus3pt minus2pt}{2pt}
\titlespacing*{\subsubsection}{0pc}{2ex plus2.5pt minus1.5pt}{2pt}
\titlespacing*{\paragraph}{0pc}{2ex plus2pt minus1pt}{0pt}


%%======== Captions in tables and figures ========
\DeclareCaptionLabelSeparator{pipe}{ $\vert$ }% or $\vert$
\captionsetup{          % 只影响表格；若想图也一样，去掉 [table]
  labelfont       = {bf,color=gblue9},
  labelsep        = pipe,
  % % format          = hang,
  % justification   = centerfirst,
  % singlelinecheck = off         % 单行也遵循同样对齐
  % % 不写 width=...  ← 让 caption 宽度自动=最长那一行，
}        
