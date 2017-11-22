use strict;
use warnings;
use LWP::Simple;
use File::Spec;
#use Data::Dumper;
use utf8;

# CHANGELOG
# v1, 08/2015, Pavel Jurca
# v1.1, 09/2015, Pavel Jurca
#   — rezervace mimo pravidelny cas
#   — text 'REZERVACE' na miste IDENTu
#   — placeholder v pripade volneho dne

# TODO
# https://metacpan.org/pod/HTTP::Tiny#request 
# Accept-Language: cs


### ============== MAIN =============
use constant API
    # live
    => 'REDACTED'
    # debug
    # => 'http://localhost:8080/rozvrh.html?'
;
use constant ROZVRHY
    => qw( 7:30 9:15 11:00 12:45 14:30 16:15 18:00 )
;
my %ucebna = (
            # INSIS id
    'JM 357'  => 752,
    'JM 359'  => 746,
    'JM 360'  => 2281,
    'JM 361'  => 790,
    'JM 382'  => 700,
    'JM 352'  => 4870, # studovna
);

tisk_panely(rozvrhy(values %ucebna));
### ============ END ================



=head2 rozvrhy

stahne a zpracuje rozvrhy pro dnesni den

 Returns : % rozvrh_ref
 Args    : @ ucebny

=cut

sub rozvrhy {
    my @uceb_id = @_;

    my %rozvrh;
    for my $ucebna (@uceb_id) {
        # HTTP GET :iso-8859-2
        my $html = do {
            my $r;
            # 3 pokusy o spojeni
            for (1..3) {
                $r = get(API . $ucebna);
                last if $r;
            }

            $r;
        };
        die "(!) isis neodpovida\n" unless $html;

        for my $_rozvrh (_html($html)) {
            my @predmet = @{ $_rozvrh };

            my $od = shift @predmet;
            my $do = shift @predmet;
            # min. sirka sloupce
            my $predm = sprintf "%-6s " x @predmet, @predmet;

            # prazdne mezery pryc
            $predm =~ s/^\s+|\s+$//g;

            for my $cas (ROZVRHY) {
                my ($_od, $_do, $_cas) = map {
                    (my $num = $_) =~ s/\D//g;
                    $num;
                } ($od, $do, $cas);

                # ulozi i rezervace pres vice hodin
                $rozvrh{$cas}{$ucebna} = $predm
                    if ($_cas >= $_od and $_cas < $_do);
            }
        }
    }

    return \%rozvrh;
}

=head2 _html

vyjme udaje z HTML rozvrhu,
ocisti a filtruje konkretni sloupce

 Returns : @ predmety
 Args    : text 

=cut

sub _html {
    my $html = shift;

    # ucebna je cely den prazdna
    return if $html !~ /<thead>/;

    my (@predmety, @tr);
    for (split m|</td>|, $html) {
        # chomp;
        if (m|</tr| && @tr > 5) {

            # Vyucujici, jen prijmeni
            my ($prijm) = split(/,/, $tr[5], 2);
            ($prijm) = $prijm =~ /[ ]?(\S*)$/;

            # Kod
            $tr[3] = 'REZERVACE'
                if $tr[4] =~ s/(reservation|rezervace):&nbsp;//i;

            # TECHNICAL MAINTENANCE STAFF hack
            $tr[3] = "Technická údržba",
              $prijm = "" if $prijm =~ /REDACTED|REDACTED|REDACTED/;

            push @predmety, [
                              $tr[0], # Od
                              $tr[1], # Do
                              $tr[3], # Kod
                              $prijm, # Vyucujici
                          ];
            @tr = (); #flip-flop
        }

        my ($td) = m|>([^<]+)</small>$|;
        # no space, tab or newline
        $td =~ s/^\s+|\s+$//g if $td;

        push @tr, $td || ' ';
    }

    # rozvrh pro danou ucebnu
    return @predmety;
}

=head2 tisk_panely

zapise do souboru 0730.325, 0915.325,
1100.325 apod. obrazovky panelu

(!) cokoliv nad 127 ASCII je treba kodovat

 Args    : % rozvrh_ref

=cut

sub tisk_panely {
    my $rozvrh_ref = shift;

    my @panel;
    for (my $i = 0; $i < (ROZVRHY); $i++) {
        my $cas = (ROZVRHY)[$i];

        my @_panel;
        if (keys %{ $rozvrh_ref }) {

            @_panel = ' ' x 9 . "|od ${cas}h|";

            for my $uceb (reverse sort keys %ucebna) {
                my $predm = \$rozvrh_ref->{$cas}{ $ucebna{$uceb} };
                push @_panel, $uceb . '  ' . ( $$predm || 'n/a' );
            }
        }
        else {
            # CELY DEN VOLNO
            push @_panel,
                    '',
                    (map { ' ' x 6 . $_ } qw/Vysoká škola ekonomická/),
                    '',
                    ' ' x 6 . 'Jižní Město'
            ;
        }

        # panel je formou 2 subpanelu
        # po 5 udajich kazdy (viz pocet uceben)
        push @panel, [ @_panel ];

            # Probiha / Nasleduje
        if (@panel == 2) {
            SOUBOR:
            {
                (my $soubor = (ROZVRHY)[$i-$#panel]) =~ s/\D//g;
                $soubor = sprintf "%04s", $soubor;

                my $cesta = File::Spec->catpath(
                    'C:',
                    File::Spec->catdir('', 'PANEL', 'TEXTS'),
                    $soubor . '.325'
                );

                #========== zacatek SOUBORU ===========

                open(my $fh, '>', $cesta)
                    or die "(!) nelze zapsat do '$cesta'\n";

                # DEBUG
                # my $fh = *STDOUT;
                # LIVE
                binmode $fh, ':bytes';

                # kontrolni znaky ~ 1 radek
                print $fh
                    '33', # 3,3 mod animace
                    '55', # 55s prodleva
                    "\n"
                ;

                  #====== OBSAH panelu ======

                  # zahlavi ~ 1 radek
                  print $fh
                      # den   # mesic
                      "%d. \x{BC}\x{BD}.",
                      ' ' x 2,
                      zakoduj('VŠE v Praze'),
                      ' ' x 2,  # vteriny
                      "%H:%M:\x{B8}\x{B9}",
                      "\n"
                  ;

                  # telo ~ 14 radku
                  print $fh
                      zakoduj(
                          join "\n", map {
                              # $_ // ''
                              defined $_ ? $_ : ''
                          } (map @$_, @panel[0..$#panel])[0..13]
                      ),
                      "\n"
                  ;

                  #=========================

                # kontrolni znaky ~ 15 radku
                print $fh
                    "\x{0F}" x 30, "\n" for (1..15)
                ;

                close $fh;

                #=====================================

                # Nasleduje => Probiha
                shift @panel;

                # posledni rozvrh dne
                redo SOUBOR if $i + @panel == (ROZVRHY);
            }
        }
    }

    print "(i) zapsano\n";
}

=head2 zakoduj

zakoduje text dle sady
pro panel SPECTRUM

 Returns : text
 Args    : text

=cut

sub zakoduj {
    my $text = shift;

    # znakova sada SPECTRUM 
    my %sada = (
        'A'  => "\x{41}",
        'Á'  => "\x{80}",
        'Ä'  => "\x{8E}",
        'B'  => "\x{42}",
        'C'  => "\x{43}",
        'Č'  => "\x{AC}",
        'D'  => "\x{44}",
        'Ď'  => "\x{D2}",
        'E'  => "\x{45}",
        'É'  => "\x{90}",
        'Ě'  => "\x{B7}",
        'Ë'  => "\x{45}",
        'F'  => "\x{46}",
        'G'  => "\x{47}",
        'H'  => "\x{48}",
        'I'  => "\x{49}",
        'Í'  => "\x{D6}",
        'Ï'  => "\x{8B}",
        'J'  => "\x{4A}",
        'K'  => "\x{4B}",
        'L'  => "\x{4C}",
        'Ľ'  => "\x{6C}",
        'M'  => "\x{4D}",
        'N'  => "\x{4E}",
        'Ň'  => "\x{D5}",
        'O'  => "\x{4F}",
        'Ó'  => "\x{E0}",
        'Ö'  => "\x{99}",
        'P'  => "\x{50}",
        'Q'  => "\x{51}",
        'R'  => "\x{52}",
        'Ř'  => "\x{FC}",
        'S'  => "\x{53}",
        'Š'  => "\x{8D}",
        'T'  => "\x{54}",
        'Ť'  => "\x{9C}",
        'U'  => "\x{55}",
        'Ú'  => "\x{8F}",
        'Ů'  => "\x{8C}",
        'Ü'  => "\x{9A}",
        'V'  => "\x{56}",
        'W'  => "\x{57}",
        'X'  => "\x{58}",
        'Y'  => "\x{59}",
        'Ý'  => "\x{ED}",
        'Ž'  => "\x{A7}",
        'a'  => "\x{61}",
        'á'  => "\x{A0}",
        'ä'  => "\x{84}",
        'b'  => "\x{62}",
        'c'  => "\x{63}",
        'č'  => "\x{9F}",
        'd'  => "\x{64}",
        'ď'  => "\x{88}",
        'e'  => "\x{65}",
        'é'  => "\x{82}",
        'ě'  => "\x{D8}",
        'ë'  => "\x{89}",
        'f'  => "\x{66}",
        'g'  => "\x{67}",
        'h'  => "\x{68}",
        'i'  => "\x{69}",
        'í'  => "\x{A1}",
        'ï'  => "\x{8B}",
        'j'  => "\x{6A}",
        'k'  => "\x{6B}",
        'l'  => "\x{6C}",
        'ľ'  => "\x{4C}",
        'm'  => "\x{6D}",
        'n'  => "\x{6E}",
        'ň'  => "\x{E5}",
        'o'  => "\x{6F}",
        'ó'  => "\x{A2}",
        'ö'  => "\x{94}",
        'p'  => "\x{70}",
        'q'  => "\x{71}",
        'r'  => "\x{72}",
        'ř'  => "\x{FD}",
        's'  => "\x{73}",
        'š'  => "\x{E7}",
        't'  => "\x{74}",
        'ť'  => "\x{9B}",
        'u'  => "\x{75}",
        'ú'  => "\x{A3}",
        'ů'  => "\x{85}",
        'ü'  => "\x{81}",
        'v'  => "\x{76}",
        'w'  => "\x{77}",
        'x'  => "\x{78}",
        'y'  => "\x{79}",
        'ý'  => "\x{EC}",
        'ž'  => "\x{A7}",
    );

    return join '', map {
          $sada{$_} || (ord $_ < 128 ? $_ : '?')
      } split //, $text
    ;
}
