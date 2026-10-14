requires 'perl', '5.020';
requires 'Getopt::Long';
requires 'Text::Levenshtein';

on 'test' => sub {
    requires 'Test::More';
};
