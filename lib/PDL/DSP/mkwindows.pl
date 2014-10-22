use strict;
use warnings;

$PDL::DSP::Windows::VERSION = '0.002';

=head1 mkwindows.pl

    Script to write Windows.pm.

=cut

our %winsubs;
our %winpersubs;
our %windoc;
our %fullname;
our %window_definitions;
our %signature;

open my $OH , '>', './Windows.pm' or die "Can't open ./Windows.pm for writing";

# doc for cos_mult_to_pow is at bottom of this file. This routine is used both in
# in this script and written into the output.
my $Cpwtm = <<'EOFUNC';

sub cos_mult_to_pow {
    my( @ain )  = @_;
    barf("cos_mult_to_pow: number of args not less than 8.") if @ain > 7;
    my $ex = 7 - @ain;
    my @a = (@ain, (0) x $ex);
    my (@cs) = (
        -$a[6]+$a[4]-$a[2]+$a[0], -5*$a[5]+3*$a[3]-$a[1], 18*$a[6]-8*$a[4]+2*$a[2], 20*$a[5]-4*$a[3],
        8*$a[4]-48*$a[6], -16*$a[5], 32*$a[6]);
    foreach (1..$ex) {pop (@cs)}
    @cs;
}

EOFUNC

eval $Cpwtm;
die 'Compiling cos_mult_to_pow : ' . $@ if $@;

=for comment

-------------------------------------------------------------------
       Routines to write code defining pdls of range of points
       used in window functions.
-------------------------------------------------------------------

=cut

# make limits for both periodic and symmetric windows
sub xlims {
    my ($periodic,$xlo,$xhi) = @_;
    return "$xlo,$xhi" unless $periodic;
    return "$xlo, $xhi*(\$N-1)/\$N" if isnum($xlo) and $xlo == 0;
    return "$xlo, ($xlo+$xhi*(\$N-1))/\$N";
}

# make array with either limit string, or computed limit string.
sub mkarr {
    my ($limstr,$periodic,$xlo,$xhi);
    $limstr =  @_ == 1 ? shift :
        xlims(@_);
    "zeroes(\$N)->xlinvals($limstr)";
}

# add suffix to symmetric window names
sub add_periodic_name_suffix {
    my ($periodic,$name) = @_;
    return $name unless $periodic;
    return $name . '_per';
}

sub trig_array {
    my ($periodic, $trig_func, $xlo, $xhi) = @_;
    my $xlo_pr = $xlo eq '-(PI)' ? '-PI' : $xlo;
    my $xhi_pr = $xhi eq 'TPI' ? '2PI' : $xhi;
    return "are the $trig_func of points ranging from $xlo_pr through $xhi_pr" if $periodic eq 'doc';
    $trig_func . '(' . mkarr($periodic,$xlo,$xhi) . ')';
}

sub cos_array_1 {
    my ($periodic) = @_;
    trig_array($periodic, 'cos', 0, 'TPI');
} 

sub cos_array_2 {
    my ($periodic) = @_;
    trig_array($periodic, 'cos', '-(PI)', 'PI');
} 

sub sin_array_a {
    my ($periodic) = @_;
    trig_array($periodic, 'sin', 0, 'PI');
} 

# use with hann_matlab to avoid zeroes at ends of window
sub cos_array_3 {
    my ($periodic) = @_;
    return 'are the cosine of points ranging from 2PI/($N+1) through 2PI*$N/($N+1)' if $periodic eq 'doc';
    'cos(' . mkarr('TPI/($N+1),TPI *$N /($N+1)') . ')';
} 

# convert numeric coefficients a to coefficients c, and
# write Blackman-Harris code.
sub coscode_a_coeff {
    my (@a) = @_;
    coscode_c_coeff (cos_mult_to_pow(@a));
}

sub coscode_symbolic {
    my (@a) = @_;
    return coscode_c_coeff( $a[0], "-$a[1]") if @a == 2;
    return coscode_c_coeff( "$a[0] - $a[2]", "-$a[1]", "2*$a[2]" ) if @a == 3;
    return coscode_c_coeff( "$a[0] - $a[2]", "-$a[1] + 3 * $a[3]", 
                       "2*$a[2]", "-4*$a[3]" ) if @a == 4;
    return coscode_c_coeff( "$a[0] - $a[2] + $a[4]", "-$a[1] + 3 * $a[3]", 
                       "2*$a[2] -8*$a[4]", "-4*$a[3]", "8*$a[4]" ) if @a == 5;
}

sub coscode_c_coeff {
    my (@c) = @_;
    return "$c[0] + $c[1] * arr" if (@c == 2);
    my $pream = "my \$cx = arr;\n";
    return "$pream
    ($c[0]) +  (\$cx * (($c[1]) +  (\$cx * ($c[2]))))" if (@c == 3);
    return "$pream  
    ($c[0]) +  (\$cx * (($c[1]) +  (\$cx * ($c[2] + \$cx * ($c[3])  ))))" if (@c == 4);
    return "$pream  
    ($c[0]) +  (\$cx * (($c[1]) +  (\$cx * ($c[2] + \$cx * ($c[3] +\$cx *($c[4]))  ))))" if (@c == 5);
}

# Equivalent to array from -1 to 1 with $N+2 points, and
# the two end points removed.
sub nn_nn {
    my ($periodic) = @_;
    return 'range from -$N/($N-1) through $N/($N-1)' if $periodic eq 'doc';
    return $periodic ? 
        mkarr('-$N/($N+1),-1/($N+1)+($N-1)/($N+1)') :
        mkarr('-($N-1)/$N,($N-1)/$N');
}

sub m_one_one {
    my ($periodic) = @_;
    return 'range from -1 through 1' if $periodic eq 'doc';
    mkarr($periodic,-1,1);
}

sub m_half_half {
    my ($periodic) = @_;
    return 'range from -1/2 through 1/2' if $periodic eq 'doc';
    mkarr($periodic,-.5,.5);
}

sub mk_cos_array_1 {
    my ($h) = @_;
    $h->{arrcode} = \&cos_array_1;
}

# Only works for this application!
#sub isnum3 {
#    $_[0] =~ /^[\+\-\d\.\/]+$/;
#}

sub isnum ($) {
    return 0 if $_[0] eq ''; # not needed here
    $_[0] ^ $_[0] ? 0 : 1
}

sub mk_cos_array_1_coscode_a_coeff {
    my ($h,$a) = @_;
    mk_cos_array_1($h);
    $h->{wincode} = isnum($a->[0]) ? 
        coscode_a_coeff(@$a) :
        coscode_symbolic(@$a);
    $h;
}

=for comment

-------------------------------------------------------------------
 
    Specification for subroutines generating specific named window functions.

    %window_definitions -- hash defining window functions. Information
    in this hash describes how to write the window function sub, write
    the documentation, and anything else.

    hash key -- 'subname'; the subroutine name for the window function

     For each hash key 'subname', the value is a hash ref with the following keys. Most
     of these are optional. Or supply undef to be explicit.
     
    arrcode  -- code ref that writes code generating 
        an pdl array of points used in several windows. 
        Eg $N points from -1 to 1 , or cos(0) to cos(PI), etc.

    arrcode1 -- another array of points. Some windows need two.

    wincode -- code written into window sub beneath the code generated by arrcode.
        The string 'arr' will be substituted with code generating a piddle defined
        by arrcode.

    periodic_wincode -- like wincode, but defines code for periodic window function. For most
          windows, wincode is sufficient, because a parameter is passed to arrcode which
          is sufficient to choose between symmetric and periodic. In more complicated cases,
          wincode is used for symmetric, and periodic_wincode for periodic.

    noper -- If set, no periodic version of the window is generated.

    params -- parameter(s) that the window function takes (other than $N).
           (a string or array of strings)

    fn -- A window name for use in docs. If omitted, the capitalized sub name is used. If string
          begins with '*', then an entire descriptive sentence is expected, rather than
          just a proper name.

    pfn -- An optional shorter window name. If 'fn' is long, pfn is returned by method get_name.
           For use in plot titles, etc. Also written first in main doc entry for 'subname'.

    descr -- An optional description written into the doc for 'subname'.

    alias -- other names for the window function. This is only used in the documentation.
             string or array of strings. It is not an alias for any software identifier.p

    note -- A note written at the end of the doc entry for this window 'subname'.

    ref -- number for citing our source for the window definition. This cites a source listed
           at the bottom of the docs.

    seealso -- link to other routines in this package

    octave, matlab -- equivalent routine name in alien software

    skip -- skip this window definition. Do not process it. For debugging/broken code.

-------------------------------------------------------------------

=cut

# ref  = 1 means IEEE article by Harris

%window_definitions = (

    blackman_gen => { # JOS: general classic blackman
        arrcode => \&cos_array_1,
        wincode => coscode_c_coeff( '.5 - $alpha' , '-.5' , '$alpha' ),
#        wincode => coscode_symbolic( '(1 - $alpha)/2' , '.5' , '$alpha/2' ),
        params => '$alpha',
        pfn => 'General classic Blackman',
        fn => '*A single parameter family of the 3-term Blackman window. '
    },
    cos_alpha => {  # JOS 
        arrcode => \&sin_array_a,
        wincode => ' arr**$alpha ',
        params => '$alpha',
        ref => 1,
        alias => 'Power-of-cosine'
    },
    hann_matlab => {   #  like matlab hanning
        arrcode => \&cos_array_3,
        wincode => '0.5 - 0.5 * arr',
        pfn => 'Hann (matlab)',
        fn => '*Equivalent to the Hann window of N+2 points, with the endpoints (which are both zero) removed.',
        matlab => 'hanning',
        noper => 1,
        seealso => 'hann'
    },
    cosine => {
        arrcode => \&sin_array_a,
        wincode => 'arr',
        alias => 'sine'
    },
    rectangular => {
        wincode => 'ones($N)',
        alias => [ 'dirichlet', 'boxcar' ],
        ref => 1,
#        noper => 1
    },
    bartlett => {
        arrcode => \&m_one_one,
        wincode => '1 - abs arr',
        ref => 1,
        alias => [ 'fejer' ],
        seealso => 'triangular'
    },
    triangular => {
        arrcode => \&nn_nn,
        wincode => '1 - abs arr',
        seealso => 'bartlett'
#        alias => ['parzen'] 
    },
    welch => {
        arrcode => \&m_one_one,
        wincode => '1 - arr**2',
        ref => 1,
        alias => ['Riez', 'Bochner', 'Parzen', 'parabolic']
    },
    exponential => {  # from pdl audio
        arrcode => \&m_one_one,
        wincode => '2 ** (1 - abs arr) - 1'
    },
    cauchy => {  
        arrcode => \&m_one_one,
        wincode => '1 / (1 + (arr * $alpha)**2)',
        params => '$alpha',
        alias => ['Abel', 'Poisson'],
        ref => 1
    },
    poisson => {  
        arrcode => \&m_one_one,
        wincode => 'exp (-$alpha * abs arr)',
        params => '$alpha',
        ref => 1
    },
    gaussian => {  
        arrcode => \&m_one_one,
        wincode => 'exp (-0.5 * ($beta * arr )**2)',
        params => '$beta',
        alias => 'Weierstrass',
        ref => 1
    },
    bartlett_hann => {
        arrcode => \&m_half_half,
        arrcode1 => \&cos_array_2,
        wincode => '0.62 - 0.48 * abs arr + 0.38* arr1',
        fn => 'Bartlett-Hann',
        alias => 'Modified Bartlett-Hann'
    },
    hann_poisson => {
        arrcode => \&m_one_one,
        arrcode1 => \&cos_array_2,
        wincode => '0.5 * (1 + arr1) * exp (-$alpha * abs arr)',
        params => '$alpha',
        fn => 'Hann-Poisson',
        ref => 1
    },
    bohman => {
        arrcode => \&m_one_one,
        wincode => 'my $x = abs(arr);' . "\n" . 
                  '(1-$x)*cos(PI*$x) +(1/PI)*sin(PI*$x)',
        ref => 1
    },
    lanczos => {
        alias => 'sinc',
        arrcode => \&m_one_one,
        wincode => '
 my $x = PI * arr;
 my $res = sin($x)/$x;
 my $mid;
 $mid = int($N/2), $res->slice($mid) .= 1 if $N % 2;
 $res;',
        periodic_wincode => '
 my $x = PI * arr;
 my $res = sin($x)/$x;
 my $mid;
 $mid = int($N/2), $res->slice($mid) .= 1 unless $N % 2;
 $res;'

    },
);


# format a coefficients for printing in document. Used in Blackman-Harris windows
sub format_coeffs_a {
    my ($a) = @_;
    my $i=0;
    my @s;
    foreach(@$a) {
        push @s, "a$i = " . $_;
        $i++;
    }
    join(', ',@s);
}


# define the blackman-harris family of windows.
foreach (
    [ hamming => [0.54, 0.46], {ref => 1 }  ],
    [ hamming_ex => [0.53836, 0.46164] , { fn => q!'exact' Hamming!, ref => 1}  ],
    [ hamming_gen => [ '$a', '(1-$a)' ] , 
      { params => '$a', fn => 'general Hamming', ref => 1 }],
    [ hann => [0.5, 0.5], {ref => 1 , alias => 'hanning', seealso => 'hann_matlab' } ],
    [ blackman => [.42, .5, .08] , {fn => q!'classic' Blackman!, ref=>1} ], # JOS, wikip, octave: classic blackman
    [ blackman_ex => [7938/18608, 9240/18608, 1430/18608],
             {fn => q!'exact' Blackman!, ref => 1} ], # exact blackman 
    [ blackman_bnh => [.4243801, .4973406, .0782793],
             {pfn => 'Blackman-Harris (bnh)', 
              fn => '*An improved version of the 3-term Blackman-Harris window given by Nuttall (Ref 2, p. 89).' }],
    [ blackman_harris => [0.422323, 0.49755,  0.07922 ] , {fn => 'Blackman-Harris', ref => 1,
             alias => 'Minimum three term (sample) Blackman-Harris' } ],
    [ blackman_gen3 => [ '$a0', '$a1', '$a2' ],
      { params => [ qw($a0 $a1 $a2 ) ] , fn => '*The general form of the Blackman family. ' } ],
    [ blackman_gen4 => ['$a0', '$a1', '$a2', '$a3'],
      { params => [ qw($a0 $a1 $a2 $a3 ) ], fn => '*The general 4-term Blackman-Harris window. ' }],
    [ blackman_gen5 => ['$a0', '$a1', '$a2','$a3','$a4'],
      {params =>  [ qw($a0 $a1 $a2 $a3 $a4) ],  fn => '*The general 5-term Blackman-Harris window. ' }],
    [ nuttall1 => [0.355768, 0.487396, 0.144232, 0.012604],
      {pfn => 'Nuttall (v1)', fn=> '*A window referred to as the Nuttall window.', seealso => 'nuttall',
      octave => 'nuttallwin' } ],
    [ nuttall => [0.3635819,0.4891775,0.1365995,.0106411], {seealso => 'nuttall1'} ],
    [ blackman_harris4 => [0.35875,0.48829,0.14128,0.01168], 
        {fn=> 'minimum (sidelobe) four term Blackman-Harris', ref => 1, alias => 'Blackman-Harris'} ],
    [ blackman_nuttall => [0.3635819,0.4891775,0.1365995,0.0106411], {fn=> 'Blackman-Nuttall'} ],
    [ flattop => [0.21557895,0.41663158,0.277263158,.083578947,0.006947368],
      {fn => 'flat top'} ] # matlab, octave have different scale by 1 part in 10^-4 or so.
    ) 
{
    my ($name,$a,$h) = @{$_};
    $h = {} unless $h;
    $h->{descr} = "One of the Blackman-Harris family, with coefficients\n\n ".
        format_coeffs_a($a) . "\n";
    $window_definitions{$name} = mk_cos_array_1_coscode_a_coeff($h,$a);
    $windoc{$name} = "One of the Blackman-Harris family, with coefficients\n\n ".
        format_coeffs_a($a) . "\n";
    $window_definitions{$name}->{nocodedoc} = 1.
}

sub _mk_tukey {
    my($periodic) = @_;
    my ($sub1,$sub2);
    $sub1 = $periodic ? '($N-1)/$N' : '1';
    $sub2 = $periodic ? '1' : '0';
    my $code = q{
  barf("tukey: alpha must be between 0 and 1") unless
         $alpha >=0 and $alpha <= 1;
  return ones($N) if $alpha == 0;
  my $x = zeroes($N)->xlinvals(0,SUB1);
  my $x1 = $x->where($x < $alpha/2);
  my $x2 = $x->where( ($x <= 1-$alpha/2) & ($x >= $alpha/2) ); 
  my $x3 = $x->where($x > 1 - $alpha/2);
  $x1 .= 0.5 * ( 1 + cos( PI * (2*$x1/$alpha -1)));
  $x2 .= 1;
  $x3 .= $x1->slice('-1:SUB2:-1');
  return $x};
  $code =~ s/SUB1/$sub1/;
  $code =~ s/SUB2/$sub2/;
  $code;
}

$window_definitions{tukey} = {
        arrcode => undef,
        params =>  '$alpha',
        wincode => _mk_tukey(0),
        periodic_wincode => _mk_tukey(1),
        alias => 'tapered cosine',
        ref => 1
};

sub _mk_parzen {
    my($periodic) = @_;
    my ($sub1,$sub2);
    $sub1 = $periodic ? '(-1 + ($N-1))/($N)' : '1';
    $sub2 = $periodic ? '1' : '0';
    my $code = q{
  my $x = zeroes($N)->xlinvals(-1,SUB1);
  my $x1 = $x->where($x <= -.5);
  my $x2 = $x->where( ($x < .5)  & ($x > -.5) ); 
  my $x3 = $x->where($x >= .5);
  $x1 .= 2 * (1-abs($x1))**3;
#  $x3 .= 2 * (1-abs($x3))**3;
  $x3 .= $x1->slice('-1:SUB2:-1');
  $x2 .= 1 - 6 * $x2**2 *(1-abs($x2));
  return $x};
  $code =~ s/SUB1/$sub1/;
  $code =~ s/SUB2/$sub2/;
  $code;
}

$window_definitions{parzen} = {
        arrcode => undef,
        wincode => _mk_parzen(0),
        periodic_wincode => _mk_parzen(1),
        alias => ['Jackson', 'Valle-Poussin'],
        ref => 1,
        note => 'This function disagrees with the Octave subroutine B<parzenwin>, but agrees with Ref. 1.',
        seealso => 'parzen_octave'
};

$window_definitions{parzen_octave} = {
    arrcode => undef,
    noper => 1,
    fn => 'Parzen',
    octave => 'parzenwin',
    seealso => 'parzen',
    wincode => q{
        my $L = $N-1;
        my $r = ($L/2);
        my $r4 = ($r/2);
        my $n = sequence(2*$r+1)-$r;
        my $n1 = $n->where(abs($n) <= $r4);
        my $n2 = $n->where($n > $r4);
        my $n3 = $n->where($n < -$r4);
        $n1 .= 1 -6.*(abs($n1)/($N/2))**2 + 6*(abs($n1)/($N/2))**3;
        $n2 .= 2.*(1-abs($n2)/($N/2))**3;        
        $n3 .= 2.*(1-abs($n3)/($N/2))**3;
        $n;
    }
};

$window_definitions{chebyshev} = {
    alias => 'Dolph-Chebyshev',
    params => '$at',
    noper => 1,
    octave => 'chebwin',
    descr => 'The frequency response of this window has C<$at> dB of attenuation in the stop-band.',
    wincode => q{
    my ($M,$M1,$pos,$pos1);
    my $cw;
    my $beta = cosh(1/($N-1) * acosh(1/(10**(-$at/20))));
    my $k = sequence($N);
    my $x = $beta * cos(PI*$k/$N);
    $cw = chebpoly($N-1,$x);
    if ( $N % 2 ) {  # odd
        $M1 = ($N+1)/2;
        $M = $M1 - 1;
        $pos = 0;
        $pos1 = 1;
        PDL::FFT::realfft($cw);
    }
    else { # half-sample delay (even order)
        my $arg = PI/$N * sequence($N);
        my $cw_im = $cw * sin($arg);
        $cw *= cos($arg);
        PDL::FFT::fftnd($cw,$cw_im);
        $M1 = $N/2;
        $M = $M1-1;
        $pos = 1;
        $pos1 = 0;
    }
    $cw /= ($cw->at($pos));
    my $cwout = zeroes($N);
    $cwout->slice("0:$M") .= $cw->slice("$M:0:-1");
    $cwout->slice("$M1:-1") .= $cw->slice("$pos1:$M");
    $cwout /= max($cwout);
    $cwout;
   }
};


sub _mk_dpss {
    my($periodic) = @_;
    my $sub1 = $periodic ? "\$N++;\n" : '';
    my $sub2 = $periodic ? ',0:-2' : '';
        $sub1 .
    q^  
        barf 'dpss: PDL::LinearAlgebra not installed.' unless $HAVE_LinearAlgebra;
        barf "dpss: $beta not between 0 and $N." unless
              $beta >= 0 and $beta <= $N;
        $beta /= ($N/2);
        my $k = sequence($N);
        my $s = sin(PI*$beta*$k)/$k;
        $s->slice('0') .= $beta;
        my ($ev,$e) = eigens_sym(PDL::LinearAlgebra::Special::mtoeplitz($s));
        my $i = $e->maximum_ind;
        $ev->slice("($i)^ . $sub2 . q^")->copy;
    ^;
}

$window_definitions{dpss} = {
    params => '$beta',
    fn => 'Digital Prolate Spheroidal Sequence (DPSS)',
    alias => 'sleppian',
    descr => 'The parameter C<$beta> is the half-width of the mainlobe, measured in frequency bins. ' .
        'This window maximizes the power in the mainlobe '.
        'for given C<$N> and C<$beta>.',
    wincode =>    _mk_dpss(0),
    periodic_wincode => _mk_dpss(1),
};

# pdl audio code uses m_one_nn, which appears to be wrong, excpet maybe for periodic
$window_definitions{kaiser} =
     { 
        descr => 'The parameter C<$beta> is the approximate half-width of the mainlobe, measured in frequency bins.',
        arrcode => \&m_one_one,
        wincode => ' 
              barf "kaiser: PDL::GSLSF not installed" unless $HAVE_BESSEL;
              $beta *= PI;
              my @n = PDL::GSLSF::BESSEL::gsl_sf_bessel_In ($beta * sqrt(1 - arr **2),0);
        my @d = PDL::GSLSF::BESSEL::gsl_sf_bessel_In($beta,0);
        (shift @n)/(shift @d)',
        params => '$beta',
        alias => ['Kaiser-Bessel'],
        ref => 1
     };

# list periodic window function names
sub window_definitions_pernames {
    my @res;
    foreach (sort keys %window_definitions) {
        push @res, $_ . '_per' unless $window_definitions{$_}->{noper};
    }
    @res;
}

# parameter list for window function code
sub mkparamlist {
    my ($ps) = @_;
    my $res = '($N';
    return (1,"$res)") unless $ps;
    $ps = [$ps] unless ref $ps;
    return (1+scalar(@$ps), "$res," . join(',',@$ps) . ')' );
}


sub generate_window_code {
    my ($arr,$arr1,$wincode,$num_args);
    foreach my $name (sort keys %window_definitions) {
        my $h = $window_definitions{$name};
        delete $h->{$name}, next if $h->{skip};
        $fullname{$name} = $h->{fn} || ucfirst($name);
        foreach my $periodic (0,1) {
            next if $periodic and $h->{noper};
            $arr1 = $h->{arrcode1} ? ($h->{arrcode1}->($periodic)) : '';
            $wincode = ($h->{periodic_wincode} and $periodic) ? $h->{periodic_wincode} : $h->{wincode};
            $wincode =~ s/arr1/($arr1)/;
            $arr = $h->{arrcode} ? ($h->{arrcode}->($periodic)) : '';
            $wincode =~ s/arr/($arr)/;
            $h->{params} = [$h->{params}] unless not defined $h->{params} or ref($h->{params});
            $h->{alias} = [$h->{alias}] unless not defined $h->{alias} or ref($h->{alias});
            ($num_args, $signature{$name}) = mkparamlist($h->{params} || '');
            my $code = 'sub ' . add_periodic_name_suffix($periodic,$name) . " {\n" .
                "  barf \"$name: $num_args argument" . ($num_args == 1 ? '' : 's') 
                . " expected. Got \" . scalar(\@_) . ' arguments.' unless \@_ == $num_args;\n" .
                '  my ' . $signature{$name} . " = \@_;\n" .
                "    $wincode;\n".
                "}\n";
            print $OH $code;
#            eval $code;
#            die $name . ': ' . $@ if $@;
            print $OH "\$window_definitions{$name} = {\n";
            print $OH  "pfn => q!$h->{pfn}!,\n" if $h->{pfn};
            print $OH  "fn => q!$h->{fn}!,\n" if $h->{fn};
            print $OH  'params => [ ' . join(',',  map { "'$_'" } @{$h->{params}}) . "],\n" if $h->{params};
            print $OH  'alias => [ ' . join(',',  map { "'$_'" } @{$h->{alias}}) . "],\n" if $h->{alias};
            print $OH  "};\n";
# evals below are a waste. We only use the keys later for print docs.
            if ( $periodic ) {
                eval "\$winpersubs{$name}" . '= \&' . add_periodic_name_suffix(1,$name);
                print $OH "\$winpersubs{$name}" . '= \&' . add_periodic_name_suffix(1,$name);
            }
            else {
                eval "\$winsubs{$name} = \\&$name";
                print $OH "\$winsubs{$name} = \\&$name";
            }
            print $OH  ";\n\n";
        }
    }
}

sub alien_prog_string {
  my ($prog,$func) = @_;
 "This routine gives the same result as the routine B<$func> in $prog.\n";
}

sub print_func_doc1 {
    my ($name,$nameper) = @_;
    my $wdef = $window_definitions{$name};
    my $print_fullname = '';
#    my $descr = $windoc{$name} ? $windoc{$name} . "\n" : '';
    my $descr = $wdef->{descr} ? $wdef->{descr} . "\n" : '';
    my $fullname = '';
    my $alias = '';
    my $note = '';
    $note = $wdef->{note} ."\n" if $wdef->{note};
    my $octave = '';
    $octave = alien_prog_string('Octave 3.6.2',$wdef->{octave}) if $wdef->{octave};
    my $matlab = '';
    $matlab = alien_prog_string('Matlab',$wdef->{matlab}) if $wdef->{matlab};
    my $sig = $signature{$name};
    my $seealso = '';
    die $name . ' has see also to unknown window function: "' . $wdef->{seealso} . '"'
    unless not $wdef->{seealso} or exists $window_definitions{$wdef->{seealso}};
    $seealso = 'See also L<' . $wdef->{seealso} . '|/' 
        .  $wdef->{seealso} . $sig . ">.\n" if $wdef->{seealso};
    my $periodic = $wdef->{noper} ? 
        'No periodic version of this window is defined.' ."\n" : '';
    my ($as, $fn, $pfn);
    my $codedoc = '';
    if ( defined $wdef->{arrcode} and not $wdef->{nocodedoc} ) {
        $codedoc = ' This window is defined by' . "\n\n "
            . $wdef->{wincode} . ",\n\n" .
            'where the points in arr ' . 
            $wdef->{arrcode}->('doc') ;
        $codedoc .=  $wdef->{arrcode1} ?
            ', and arr1 ' . $wdef->{arrcode1}->('doc') . ".\n" :
            ".\n";
    }
    if ($fn = $fullname{$name}) {
        $fullname = $fn =~ s/^\*// ?
            $fullname = $fn . ' ' :
            "The $fn window. ";
    }
    if ($pfn = $wdef->{pfn}) {
        $print_fullname = $pfn =~ s/^\*// ?
            $print_fullname = $pfn . ' ' :
            "The $pfn window. ";
    }
    my $ref = $wdef->{ref} ? '(Ref ' .
        $wdef->{ref} . '). ' : '';
    my $prname = $nameper || $name;
    if ($wdef->{alias}) {
        $as = $wdef->{alias};
        $as = [$as] unless ref ($as);
        $alias = scalar(@$as) == 1 ? "Another name for this window is the $as->[0] window. " :
            'Other names for this window are: ' . join(', ',@$as) . '. ';
    }
    print $OH <<"EOF1";

=head2 $prname$sig

$print_fullname$fullname$ref$descr$alias$periodic$codedoc$note$octave$matlab$seealso

=cut
                
EOF1

}

sub print_func_doc {

    print $OH <<"EOL";

=head1  Symmetric window functions


EOL

   foreach (sort keys %winsubs ) {
       print_func_doc1($_);
    }

  return();  ##### skip the periodic functions

print $OH <<"EOL";

=head1  Periodic window functions


EOL

    foreach (sort keys %winpersubs ) {
        my $nameper = add_periodic_name_suffix(1,$_);
        print_func_doc1($_,$nameper);
    }

}


=for comment

-------------------------------------------------------------------

    Writing file below this line

-------------------------------------------------------------------

=cut

print $OH  
'# This file generated by mkwindows.pl' . "\n".
'package PDL::DSP::Windows;' ."\n" .
'$PDL::DSP::Windows::VERSION = ' . "'$PDL::DSP::Windows::VERSION';\n";

print $OH  <<'EOTOP';
use base 'Exporter';
use strict;
use warnings;
use PDL::LiteF;
use PDL::FFT;
use PDL::Math qw( acos cosh acosh );
use PDL::Core qw( topdl );
use PDL::MatrixOps qw( eigens_sym );

eval { require PDL::LinearAlgebra::Special };
my $HAVE_LinearAlgebra = 1 if !$@;

eval { require PDL::GSLSF::BESSEL; };
my $HAVE_BESSEL = 1 if !$@;

eval { require PDL::Graphics::Gnuplot; };
my $HAVE_GNUPLOT = 1 if !$@;

#eval { require PDL::Graphics::PLplot; };
#my $HAVE_PLPLOT = 1 if !$@;

use PDL::Constants qw(PI);
use constant TPI => 2 * PI;

our @ISA = qw(Exporter);

EOTOP

print $OH 'our @EXPORT_OK = qw( window list_windows chebpoly cos_mult_to_pow cos_pow_to_mult
   ' . join(' ', (sort keys %window_definitions, window_definitions_pernames())) . ");\n\n";

print $OH  <<'EOTOP2';
$PDL::onlinedoc->scan(__FILE__) if $PDL::onlinedoc;

our %winsubs;
our %winpersubs;
our %window_definitions;

=head1 NAME

PDL::DSP::Windows - Window functions for signal processing

=head1 SYNOPSIS

       use PDL;
       use PDL::DSP::Windows('window');
       my $samples = window( 10, 'tukey', { params => .5 });

       use PDL;
       use PDL::DSP::Windows;
       my $win = new PDL::DSP::Windows(10, 'tukey', { params => .5 });
       print $win->coherent_gain , "\n";
       $win->plot;

=head1 DESCRIPTION

This module provides symmetric and periodic (DFT-symmetric)
window functions for use in filtering and spectral analysis.
It provides a high-level access subroutine
L</window>. This functional interface is sufficient for getting the window
samples. For analysis and plotting, etc. an object oriented
interface is provided. The functional subroutines must be either explicitly exported, or
fully qualified. In this document, the word I<function> refers only to the
mathematical window functions, while the word I<subroutine> is used to describe
code.

Window functions are also known as apodization
functions or tapering functions. In this module, each of these
functions maps a sequence of C<$N> integers to values called
a B<samples>. (To confuse matters, the word I<sample> also has
other meanings when describing window functions.)
The functions are often named for authors of journal articles.
Be aware that across the literature and software,
some functions referred to by several different names, and some names
refer to several different functions. As a result, the choice
of window names is somewhat arbitrary.

The L</kaiser> window function requires
L<PDL::GSLSF::BESSEL>. The L</dpss> window function requires
L<PDL::LinearAlgebra>. But the remaining window functions may
be used if these modules are not installed.

The most common and easiest usage of this module is indirect, via some
higher-level filtering interface, such as L<PDL::DSP::Fir::Simple>.
The next easiest usage is to return a pdl of real-space samples with the subroutine L</window>.
Finally, for analyzing window functions, object methods, such as L</new>,
L</plot>, L</plot_freq> are provided.

In the following, first the functional interface (non-object oriented) is described in
L</"FUNCTIONAL INTERFACE">. Next, the object methods are described in L</METHODS>.
Next the low-level subroutines returning samples for each named window
are described in  L</"WINDOW FUNCTIONS">. Finally,
some support routines that may be of interest are described in 
L</"AUXILIARY SUBROUTINES">.

=head1 FUNCTIONAL INTERFACE

=head2 window

       $win = window({OPTIONS});
       $win = window($N,{OPTIONS});
       $win = window($N,$name,{OPTIONS});
       $win = window($N,$name,$params,{OPTIONS});
       $win = window($N,$name,$params,$periodic);

Returns an C<$N> point window of type C<$name>.
The arguments may be passed positionally in the order
C<$N,$name,$params,$periodic>, or they may be passed by
name in the hash C<OPTIONS>.

=head3 EXAMPLES

 # Each of the following return a 100 point symmetric hamming window.

   $win = window(100);
   $win = window(100, 'hamming');
   $win = window(100, { name => 'hamming' );
   $win = window({ N=> 100, name => 'hamming' );

 # Each of the following returns a 100 point symmetric hann window.

   $win = window(100, 'hann');
   $win = window(100, { name => 'hann' );

 # Returns a 100 point periodic hann window.

   $win = window(100, 'hann', { periodic => 1 } );

 # Returns a 100 point symmetric Kaiser window with alpha=2.

   $win = window(100, 'kaiser', { params => 2 });

=head3 OPTIONS

The options follow default PDL::Options rules-- They may be abbreviated,
and are case-insensitive.

=over 

=item B<name>

(string) name of window function. Default: C<hamming>.
This selects one of the window functions listed below. Note
that the suffix '_per', for periodic, may be ommitted. It
is specified with the option C<< periodic => 1 >>
     

=item B<params>


ref to array of parameter or parameters for the  window-function
subroutine. Only some window-function subroutines take
parameters. If the subroutine takes a single parameter,
it may be given either as a number, or a list of one
number. For example C<3> or C<[3]>.

=item B<N>

number of points in window function (the same as the order
of the filter) No default value.

=item B<periodic>

If value is true, return a periodic rather than a symmetric window function. Default: 0
(that is, false. that is, symmetric.)

=back

=cut

sub window {
    my $win = new PDL::DSP::Windows(@_);
    $win->samples();
}

=head2 list_windows

     list_windows
     list_windows STR

C<list_windows> prints the names all of the available windows.
C<list_windows STR> prints only the names of windows matching
the string C<STR>.

=cut

sub list_windows {
    my ($expr) = @_;
    my @match;
    if ($expr) {
        my @alias;
        foreach (sort keys %winsubs) {
            push(@match,$_) , next if /$expr/i;
            push(@match, $_ . ' (alias ' . $alias[0] . ')') if @alias = grep(/$expr/i,@{$window_definitions{$_}->{alias}});
        }
    }
    else {
        @match = sort keys %winsubs;
    }
    print join(', ',@match),"\n";
}


=head1 METHODS

=head2 new

=for usage

  my $win = new PDL::DSP::Windows(ARGS);

=for ref

Create an instance of a Windows object. If C<ARGS> are given, the instance
is initialized. C<ARGS> are interpreted in exactly the
same way as arguments the subroutine L</window>.

=for example

For example:

  my $win1 = new PDL::DSP::Windows(8,'hann');
  my $win2 = new PDL::DSP::Windows( { N => 8, name => 'hann' } );

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};   
  bless ($self, $class);
  $self->init(@_) if (@_);
  return $self;
}

=head2 init

=for usage

  $win->init(ARGS);

=for ref

Initialize (or reinitialize) a Windows object.  ARGS are interpreted in exactly the
same way as arguments the subroutine L</window>.

=for example

For example:

  my $win = new PDL::DSP::Windows(8,'hann');
  $win->init(10,'hamming');

=cut

sub init {
    my $self = shift;

    my $opt = new PDL::Options(
        {
            name => 'hamming',
            periodic => 0,   # symmetric or periodic
            N => undef,           # order
            params => undef,
        });
    my ($N,$name,$params,$periodic);
    $N = shift unless ref ($_[0]);
    $name = shift unless ref ($_[0]);
    $params = shift unless ref ($_[0]) eq 'HASH';
    $periodic = shift unless ref ($_[0]);
    my $iopts = @_ ? shift : {};
    my $opts = $opt->options($iopts);
    $name = $opts->{name} unless $name;
    $name =~ s/_per$//;
    $N = $opts->{N} unless $N;
    $params = $opts->{params} unless defined $params;
    $params = [$params] if defined $params and not ref $params;
    $periodic = $opts->{periodic} unless $periodic;
    my $ws = $periodic ? \%winpersubs : \%winsubs;
    if ( not exists $ws->{$name}) {
        my $perstr = $periodic ? 'periodic' : 'symmetric';
        barf "window: Unknown $perstr window '$name'.";
    }
    $self->{name} = $name;
    $self->{N} = $N;
    $self->{periodic} = $periodic;
    $self->{params} = $params;
    $self->{code} = $ws->{$name};
    $self->{samples} = undef;
    $self->{modfreqs} = undef;
    return $self;
}

=head2 samples

=for usage

  $win->samples();

=for ref

Generate and return a reference to the piddle of $N samples for the window C<$win>.
This is the real-space representation of the window.
The samples are stored in the object C<$win>, but are regenerated
every time C<samples> is invoked. See the method
L</get_samples> below.

=for example

For example:

  my $win = new PDL::DSP::Windows(8,'hann');
  print $win->samples(), "\n";

=cut

sub samples {
    my $self = shift;
    my @args = defined $self->{params} ? ($self->{N}, @{$self->{params}} ) : ($self->{N});
    $self->{samples} = $self->{code}->(@args);
}

sub freqs {
    my $self = shift;
    my ($min_bins) = 1000;
    my $data = $self->get('samples');
    my $n = $data->nelem;
    my $fn = $n > $min_bins ? 2 * $n : $min_bins;
    $n--;
    my $freq = zeroes($fn);
    $freq->slice("0:$n") .= $data;
    PDL::FFT::realfft($freq);
    my $real = zeros($freq);
    my $img  = zeros($freq);
    my $mid = ($freq->nelem)/2 - 1;
    my $mid1 = $mid + 1;
    $real->slice("0:$mid") .= $freq->slice("$mid:0:-1");
    $real->slice("$mid1:-1") .= $freq->slice("0:$mid");
    $img->slice("0:$mid") .= $freq->slice("-1:$mid1:-1");
    $img->slice("$mid1:-1") .= $freq->slice("$mid1:-1");
    my $mod = $real**2 + $img**2;
    $self->{modfreqs} = $mod;
    return $mod;
}

=head2 get

=for usage

  my $windata = $win->get('samples');

=for ref

Get an attribute (or list of attributes) of the window C<$win>.
If attribute C<samples> is requested, then the samples are created with the
method L</samples> if they don't exist.

=for example

For example:

  my $win = new PDL::DSP::Windows(8,'hann');
  print $win->get('samples'), "\n";

=cut

sub get {
    my $self = shift;
    my @res;
    foreach (@_) {
        $self->samples() if $_ eq 'samples' and not defined $self->{samples};
        $self->freqs() if $_ eq 'modfreqs' and not defined $self->{modfreqs};
        push @res, $self->{$_};
    };
    return wantarray ? @res : $res[0];
}

=head2 get_samples

=for usage

  my $windata = $win->get_samples

=for ref

Return a reference to the pdl of samples for the Window instance C<$win>.
The samples will be generated with the method L</samples> if and only if
they have not yet been generated.

=cut

sub get_samples {
    my $self = shift;
    $self->{samples} ? $self->{samples} : $self->samples;
}

=head2 get_modfreqs

=for usage

  my $winfreqs = $win->get_modfreqs

=for ref

Return a reference to the pdl of the frequency response (modulus of the DFT) 
for the Window instance C<$win>. The data are created with the method L</freqs> 
if they don't exist.

=cut

sub get_modfreqs {
    my $self = shift;
    $self->{modfreqs} ? $self->{modfreqs} : $self->freqs;
}

=head2 get_params

=for usage

  my $params = $win->get_params

=for ref

Create a new array containing the parameter values for the instance C<$win>
and return a reference to the array.
Note that not all window types take parameters.

=cut

sub get_params {
    my $self = shift;
    $self->{params};
}

sub get_N {
    my $self = shift;
    $self->{N};
}

=head2 get_name

=for usage

  print  $win->get_name , "\n";

=for ref

Return a name suitable for printing associated with the window $win. This is
something like the name used in the documentation for the particular
window function. This is static data and does not depend on the instance.

=cut

sub get_name {
    my $self = shift;
    my $wd = $window_definitions{$self->{name}};
    return $wd->{pfn} . ' window' if $wd->{pfn};
    return $wd->{fn} . ' window' if $wd->{fn} and not $wd->{fn} =~ /^\*/;
    return $wd->{fn} if $wd->{fn};
    return ucfirst($self->{name}) . ' window';
}

sub get_param_names {
    my $self = shift;
    my $wd = $window_definitions{$self->{name}};
    $wd->{params} ? ref($wd->{params}) ? $wd->{params} : [$wd->{params}] : undef;
}

sub format_param_vals {
    my $self = shift;
    my $p = $self->get('params');
    return '' unless $p;
    my $names = $self->get_param_names;
    my @p = @$p;
    my @names = @$names;
    return '' unless $names;
    my @s;
    map { s/^\$// } @names;
    foreach (@p) {
        push @s, (shift @names) . ' = ' . $_;
    }
    join(', ', @s);
}

sub format_plot_param_vals {
    my $self = shift;
    my $ps = $self->format_param_vals;
    return '' unless $ps;
    ': ' . $ps;
}

=head2 plot

=for usage

    $win->plot;

=for ref

Plot the samples. Currently, only PDL::Graphics::Gnuplot is supported.
The default display type is used.

=cut

sub plot {
    my $self = shift;
    barf "PDL::DSP::Windows::plot Gnuplot not available!" unless $HAVE_GNUPLOT;
    my $w = $self->get('samples');
    my $title = $self->get_name() .$self->format_plot_param_vals;
    PDL::Graphics::Gnuplot::plot( title => $title, xlabel => 'Time (samples)',
          ylabel => 'amplitude', $w );
    return $self;
}

=head2 plot_freq

=for usage

Can be called like this

    $win->plot_freq;


Or this

    $win->plot_freq( {ordinate => ORDINATE });


=for ref

Plot the frequency response (magnitude of the DFT of the window samples). 
The response is plotted in dB, and the frequency 
(by default) as a fraction of the Nyquist frequency.
Currently, only PDL::Graphics::Gnuplot is supported.
The default display type is used.

=head3 options

=over

=item coord => COORD

This sets the units of frequency of the co-ordinate axis.
C<COORD> must be one of C<nyquist>, for
fraction of the nyquist frequency (range C<-1,1>),
C<sample>, for fraction of the sampling frequncy (range
C<-.5,.5>), or C<bin> for frequency bin number (range
C<0,$N-1>). The default value is C<nyquist>.

=back

=cut

sub plot_freq {
    my $self = shift;
    my $opt = new PDL::Options(
        {
            coord => 'nyquist'
        });
    my $iopts = @_ ? shift : {};
    my $opts = $opt->options($iopts);
    barf "PDL::DSP::Windows::plot Gnuplot not available!" unless $HAVE_GNUPLOT;
    my $mf = $self->get('modfreqs');
    $mf /= $mf->max;
    my $param_str = $self->format_plot_param_vals;
    my $title = $self->get_name() . $param_str  
        . ', frequency response. ENBW=' . sprintf("%2.3f",$self->enbw);
    my $coord = $opts->{coord};
    my ($coordinate_range,$xlab);
    if ($coord eq 'nyquist') {
        $coordinate_range = 1;
        $xlab = 'Fraction of Nyquist frequency';
    }
    elsif ($coord eq 'sample') {
        $coordinate_range = .5;
        $xlab = 'Fraction of sampling freqeuncy';
    }
    elsif ($coord eq 'bin') {
        $coordinate_range = ($self->get_N)/2;
        $xlab = 'bin';
    }
    else {
        barf "plot_freq: Unknown ordinate unit specification $coord";
    }
    my $coordinates = zeroes($mf)->xlinvals(-$coordinate_range,$coordinate_range);
    my $ylab = 'freqeuncy response (dB)';
    PDL::Graphics::Gnuplot::plot(title => $title,
       xmin => -$coordinate_range, xmax => $coordinate_range, 
       xlabel => $xlab,  ylabel => $ylab,
       with => 'line', $coordinates, 20 * log10($mf) );
    return $self;
}

=head2 enbw

=for usage

    $win->enbw;

=for ref

Compute and return the equivalent noise bandwidth of the window.

=cut

sub enbw {
    my $self = shift;
    my $w = $self->get('samples'); # hmm have to quote samples here
    ($w->nelem) * ($w**2)->sum / ($w->sum)**2;
}

=head2 coherent_gain

=for usage

    $win->coherent_gain;

=for ref

Compute and return the coherent gain (the dc gain) of the window.
This is just the average of the samples.

=cut

sub coherent_gain {
    my $self = shift;
    my $w = $self->get('samples');
    $w->sum / $w->nelem;
}


=head2 process_gain

=for usage

    $win->coherent_gain;

=for ref

Compute and return the processing gain (the dc gain) of the window.
This is just the multiplicative inverse of the C<enbw>.

=cut

sub process_gain {
    my $self = shift;
    1/$self->enbw();
}

# not quite correct for some reason.
# Seems like 10*log10(this) / 1.154 
# gives the correct answer in decibels

=head2 scallop_loss

=for usage

    $win->scallop_loss;

=for ref

**BROKEN**.
Compute and return the scalloping loss of the window.

=cut

sub scallop_loss {
    my ($w) = @_;
#    my $x = (sequence($w) - ($w->nelem/2)) * (PI/$w->nelem);
    my $x = sequence($w) * (PI/$w->nelem);
    sqrt( (($w*cos($x))->sum)**2 + (($w*sin($x))->sum)**2 ) /
        $w->sum;
}

=head1 WINDOW FUNCTIONS

These window-function subroutines return a pdl of $N samples. For most
windows, there are a symmetric and a periodic version.  The
symmetric versions are functions of $N points, uniformly
spaced, and taking values from x_lo through x_hi.  Here, a
periodic function of C< $N > points is equivalent to its
symmetric counterpart of C<$N+1> points, with the final
point omitted. The name of a periodic window-function subroutine is the
same as that for the corresponding symmetric function, except it
has the suffix C<_per>.  The descriptions below describe the
symmetric version of each window.

The term 'Blackman-Harris family' is meant to include the Hamming family
and the Blackman family. These are functions of sums of cosines.

Unless otherwise noted, the arguments in the cosines of all symmetric 
window functions are multiples of C<$N> numbers uniformly spaced
from C<0> through C<2 pi>.

=cut

EOTOP2

generate_window_code();
print_func_doc();

print $OH <<'EOENDFUNCS';

# Maxima code to convert between powers of cos and multiple angles in cos
#grind(trigsimp(trigexpand(a0 - a1*cos(x) +a2*cos(2*x) -a3*cos(3*x) + a4*cos(4*x) -a5*cos(5*x) +a6*cos(6*x))));
#
#32*a6*cos(x)^6-16*a5*cos(x)^5+(8*a4-48*a6)*cos(x)^4+(20*a5-4*a3)*cos(x)^3
#              +(18*a6-8*a4+2*a2)*cos(x)^2+(-5*a5+3*a3-a1)*cos(x)-a6+a4-a2+a0$

#(%i37) grind(trigsimp(trigreduce(c0 + c1*cos(x) 
#  + c2*cos(x)^2 + c3*cos(x)^3 + c4*cos(x)^4 + c5*cos(x)^5 + c6*cos(x)^6)));
#
#(c6*cos(6*x)+2*c5*cos(5*x)+(6*c6+4*c4)*cos(4*x)+(10*c5+8*c3)*cos(3*x)
#            +(15*c6+16*c4+16*c2)*cos(2*x)+(20*c5+24*c3+32*c1)*cos(x)+10*c6+12*c4+16*c2+32*c0)  /32$

=head1 AUXILIARY SUBROUTINES

These subroutines are used internally, but are also available for export.

=head2 cos_mult_to_pow

Convert Blackman-Harris coefficients. The BH windows are usually defined via coefficients
for cosines of integer multiples of an argument. The same windows may be written instead
as terms of powers of cosines of the same argument. These may be computed faster as they
replace evaluation of cosines with  multiplications. 
This subroutine is used internally to implement the Blackman-Harris
family of windows more efficiently. 

This subroutine takes between 1 and 7 numeric arguments  a0, a1, ...    

It converts the coefficients of this

  a0 - a1 cos(arg) + a2 cos( 2 * arg) - a3 cos( 3 * arg)  + ...

To the cofficients of this

  c0 + c1 cos(arg) + c2 cos(arg)**2 + c3 cos(arg)**3  + ...

=head2 cos_pow_to_mult

This function is the inverse of L</cos_mult_to_pow>.

This subroutine takes between 1 and 7 numeric arguments  c0, c1, ...

It converts the coefficients of this

  c0 + c1 cos(arg) + c2 cos(arg)**2 + c3 cos(arg)**3  + ...

To the cofficients of this

  a0 - a1 cos(arg) + a2 cos( 2 * arg) - a3 cos( 3 * arg)  + ...

=cut 

sub cos_pow_to_mult {
    my( @cin )  = @_;
    barf "cos_pow_to_mult: number of args not less than 8." if @cin > 7;
    my $ex = 7 - @cin;
    my @c = (@cin, (0) x $ex);
    my (@as) = (
        10*$c[6]+12*$c[4]+16*$c[2]+32*$c[0], 20*$c[5]+24*$c[3]+32*$c[1], 
         15*$c[6]+16*$c[4]+16*$c[2], 10*$c[5]+8*$c[3], 6*$c[6]+4*$c[4], 2*$c[5], $c[6]);
    foreach (1..$ex) {pop (@as)}
    my $sign = -1;
    foreach (@as) { $_ /= (-$sign*32); $sign *= -1 }
    @as;
}

=head2 chebpoly

=for usage

    chebpoly($n,$x)

=for ref

Returns the value of the C<$n>-th order Chebyshev polynomial at point C<$x>.
$n and $x may be scalar numbers, pdl's, or array refs. However,
at least one of $n and $x must be a scalar number.

All mixtures of pdls and scalars could be handled much more
easily as a PP routine. But, at this point PDL::DSP::Windows
is pure perl/pdl, requiring no C/Fortran compiler.

=cut

sub chebpoly {
    barf 'chebpoly: Two arguments expected. Got ' .scalar(@_) ."\n" unless @_==2;
    my ($n,$x) = @_;
    if (ref($x)) {
        $x = topdl($x);
        barf "chebpoly: neither $n nor $x is a scalar number" if ref($n);
        my $tn = zeroes($x);
        my ($ind1,$ind2);
        ($ind1,$ind2) = which_both(abs($x) <= 1);
        $tn->index($ind1) .= cos($n*(acos($x->index($ind1))));
        $tn->index($ind2) .= cosh($n*(acosh($x->index($ind2))));
        return $tn;
    }
    else {
        $n = topdl($n) if ref($n);
        return cos($n*(acos($x))) if abs($x) <= 1;
        return cosh($n*(acosh($x)));
    }
}

EOENDFUNCS

print $OH $Cpwtm;

print $OH <<'EOEND';
=head1 REFERENCES

=over

=item 1

Harris, F.J. C<On the use of windows for harmonic analysis with the discrete Fourier transform>,
I<Proceedings of the IEEE>, 1978, vol 66, pp 51-83.

=item 2

Nuttall, A.H. C<Some windows with very good sidelobe behavior>, I<IEEE Transactions on Acoustics, Speech, Signal Processing>,
1981, vol. ASSP-29, pp. 84-91.

=back

=head1 AUTHOR

John Lapeyre, C<< <jlapeyre at cpan.org> >>

=head1 ACKNOWLEDGMENTS

For study and comparison, the author used documents or output from:
Thomas Cokelaer's spectral analysis software; Julius O Smith III's
Spectral Audio Signal Processing web pages; André Carezia's 
chebwin.m Octave code; Other code in the Octave signal package.

=head1 LICENSE AND COPYRIGHT

Copyright 2012 John Lapeyre.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

This software is neither licensed nor distributed by The MathWorks, Inc.,
maker and liscensor of MATLAB.

=cut

1; # End of PDL::DSP::Windows.pm\n";

EOEND

1; # End of mkwindows.PL

