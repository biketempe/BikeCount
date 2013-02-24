#!/usr/bin/perl

package repop;

use strict;
use warnings;
no warnings 'uninitialized';

# use PadWalker;

our $debug = 0;
our $unparsed_text;

sub import {
    for my $fn (@_) {
        no strict 'refs';
        *{caller().'::'.$fn} = \&$fn;
    }
    1;
}

sub repop {

    # create a symbol which evaluates to the text we get here, run through both
    # the templator and the form repopulator (and also the query evaluator)

    my $text = shift;   # HTML
    my $hash = shift;   # form data

    my $code = ref $hash eq 'CODE' ? $hash : sub { $hash->{$_[0]} };
    my $state = 'normal_state';
    my $select_value; # persistant during <select><option/></select>s

    return parse_html($text, sub {

        my $accessor = shift;
        my %keyvals = @_;
      
        my $name = $keyvals{name};
        my $value = $keyvals{value};
      
        my $line = $keyvals{lit};

        goto $state;
      
        normal_state:
      
        if($keyvals{tag} eq 'select') {
            # repopulate <select>'s
            $state = 'select_state';
            $select_value = $code->($name);
            return undef; 
        } 

        if($keyvals{tag} eq 'input' && $keyvals{type} eq 'radio' && $name) {
            # todo: if the radio doesnt have a name, use the trailing text
            if($code->($name) eq $value) {
                return qq{<input type="radio" name="$name" value="$value" checked>};
            } else {
                return undef; # no-op
            }
      
        } 

        if($keyvals{tag} eq 'input' && $keyvals{type} eq 'checkbox' && $name) {
            # todo: if the checkbox doesnt have a name, use the trailing text
            if($code->($name)) {
                return qq{<input type="checkbox" name="$name" checked>};
            } else {
                return undef; # no-op
            }
      
        } 

        if($keyvals{tag} eq 'input' and $keyvals{type} eq 'text' and $name) {
            # repopulate text boxes
$debug and print "debug: got a tag ``$keyvals{tag}'' of name ``$keyvals{name}'' and our test($name) is ``@{[ $code->($name) ]}''<br>\n";
            if($code->($name)) {
                $keyvals{value} = $code->($name);
            }
            delete $keyvals{tag};
            return '<input ' . join('', map qq{$_="$keyvals{$_}" }, sort keys %keyvals) . '>';
        }

        # todo: textarea, others?

        return undef; # default case, nop

        # select_state

        select_state:

        if($keyvals{tag} eq 'option') {
            # if the option doesn't have a value tag, use the text of the option as the value
            my $kiped = '';
            my $val;
            if(exists $keyvals{value}) {
                $val = $keyvals{value}; 
            } else {
                $val = $accessor->('trailing'); $kiped=$val; $val =~s/\s+//g; 
            }
   
0 and print "<!-- debug: select_value: $select_value code($name): @{[ $code->($name) ]} val: $val -->\n";
            return $select_value eq $val ? qq{<option value="$val" selected>$kiped}
                                         : qq{<option value="$val">$kiped};
        } elsif($keyvals{tag} eq '/select') {
            $state = 'normal_state';
            $select_value = undef;
            return undef;
        } else {
            # no-op
            return undef;
        }

        return undef; # default case, nop

    });

}

# sub padwalk {
#     # look up $name in the pads up to and before this
#     my $name = shift;
#     my $pad;
#     my $depth = 2;
#     while($pad = PadWalker::peek_my($depth)) {
#         exists $pad->{'$'.$name} and last;
#     } continue {
#         $depth++;
#     }
#     $pad ?  ${ $pad->{'$'.$name} } : ();
# }

sub parse_html {
    my $file = shift;
    my $callback = shift; $callback ||= sub { return 0; };
  
    # if $callback->($accessor, %namevaluepairs) returns true, we use that return value in
    # place of the text that triggered the callback, allowing the callback to filter the HTML.
  
    my $name;
    my $text;
    my $state = 0;     # 0-outside of tag; 1-inside of tag
    my %keyvals;
    my $highwater = 0; # where in the text the last tag started
  
    my $accessor = sub {
        my $var = shift;
        return \$file if $var eq 'file';
        return \$name if $var eq 'name';
        return \$text if $var eq 'text';
        return \$state if $var eq 'state';
        return \$callback if $var eq 'callback';
        if($var eq 'trailing') { $file =~ m{\G([^<]+)}sgc; return $1; }
    };
  
    while(1) {
  
      if($file =~ m{\G(<!--.*?-->)}sgc) {
        $text .= $1;
        print "debug: comment\n" if($debug);
        my $x = $callback->($accessor, tag=>'comment', text=>$1); if(defined $x) {
          $text .= $x;
        } else {
          $text .= $1;
        }
  
      } elsif($file =~ m{\G(<script.*?</script.*?>)}isgc) {
        print "debug: script\n" if($debug);
        my $x = $callback->($accessor, tag=>'script', text=>$1); if(defined $x) {
          $text .= $x;
        } else {
          $text .= $1;
        }

      } elsif($state == 0 and $file =~ m{\G<\s*([a-z0-9]+)}isgc) {
        # start of tag
        print "debug: tag-start\n" if($debug);
        $highwater = length($text||'');
        %keyvals = (tag => lc($1));
        $state=1;
        $text .= "<" . cc($1);
  
      } elsif($state == 0 and $file =~ m{\G<\s*(/\s*[a-zA-Z0-9]+)\s*>}sgc) {
        # end tag
        $keyvals{'tag'} = lc($1); $keyvals{tag} =~ s/\s+//g;
        my $x = $callback->($accessor, %keyvals); if(defined $x) {
          $text .= $x;
        } else {
          $text .= "<".cc($1).">";
        }
        %keyvals=();
        print "debug: end-tag\n" if($debug);
  
      } elsif($file =~ m{\G(\s+)}sgc) {
        # whitespace, in or outside of tags
        if($state == 0) {
          my $x = $callback->($accessor, tag=>'lit', text=>$1); if(defined $x) {
            $text .= $x;
          } else {
            $text .= $1;
          }
        } else {
          $text .= $1;
        }
        print "debug: whitespace\n" if($debug);
  
      } elsif($state == 1 and
              ($file =~ m{\G([a-z0-9_-]+)\s*=\s*(['"])(.*?)\2}isgc or
               $file =~ m{\G([a-z0-9_-]+)\s*=\s*()([^ >]*)}isgc)) {
        # name=value pair, where value may or may not be quoted
        $keyvals{lc($1)} = $3;
        $text .= cc($1) . qq{="$3"}; # XXX need to preserve whitespace
        print "debug: name-value pair\n" if($debug);
  
      } elsif($state == 1 and
              ($file =~ m{\G([a-z0-9_-]+)}isgc)) {
        # name without a =value attached. if above doesnt match this is the fallthrough.
        $keyvals{lc($1)} = 1;
        $text .= cc($1); # correct case if needed
        print "debug: name-value pair without a value\n" if($debug);
  
      # } elsif($state == 1 and $file =~ m{\G/?\s*>}sgc) {
      } elsif($file =~ m{\G\s*/?\s*>}sgc) {
        # end of tag
        $state=0;
        my $x = $callback->($accessor, %keyvals); if(defined $x) {
          # overwrite the output with callback's return, starting from the beginning of the tag
          # $text may have changed (or been deleted) since $highwater was recorded
          substr($text, $highwater) = $x;
          $debug and print "debug: tag-end custom-case: ``$x''\n";
        } else {
          $text .= '>';
          $debug and print "debug: tag-end default case\n";
        }
        $debug and print "debug: tag-end\n";
  
      } elsif($file =~ m{\G([^<]+)}sgc and $state == 0) {
        # between tag literal data
        # $text .= $1 unless($state == 2);
        my $x = $callback->($accessor, tag=>'lit', text=>$1); if(defined $x) {
          $text .= $x;
        } else {
          $text .= $1;
        }
        print "debug: lit data\n" if($debug);
  
      } elsif($file =~ m{\G<!([^>]+)}sgc and $state != 1) {
        # DTD 
        print "debug: dtd\n" if($debug);
        $highwater = length($text);
        $text .= '<!' . cc($1);
        %keyvals = (tag => lc($1));
        $state=1;
  
      # this won't match with the lit text rule before it and it doesn't seem to do anything anyway
      #} elsif($file =~ m{\G($macro)}sgc) {  # 5.004 has issues with this
      #  # an escape of whatever format we're using for escapes
      #  print "debug: template escape\n" if($debug);
      #  # XXX if this appears in a tag, no mention will be passed to handler,
      #  # which may rewrite the tag wtihout it
      #  $text .= $1;
 
      } else {
        # this should only ever happen on end-of-string, or we have a logic error
        return $text if pos $file == length $file;
        $unparsed_text = substr $text, pos $text;
        die "HTML parse stopped at the text (between the arrows) -->$unparsed_text<--\n";
      }
    }
    # shouldnt reach this point
    return $text;
}

sub cc {
    # cruft case
    # this is here so that we can easily turn on/off munging HTML to lowercase as needed, and yes, we have needed to
    # lower-case it...
    return lc(shift);
}

# bug - <javascript> should put us in a state to treat everything as text until </javascript>.
# this applies to other tags as well, probably.

1;

__DATA__

perl -e 'use repop; my $foo = "bar"; my $baz = "quux"; print repop::repop(qq{<input type="text" name="foo">});'
perl -e 'use repop "padwalk"; sub foo { print padwalk "bar" }; sub baz { my $bar = 30; foo(); } baz;'

