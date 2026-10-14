requires 'perl', '5.020';
requires 'Encode';
requires 'File::Find';
requires 'FindBin';
requires 'Getopt::Long';
requires 'Text::Levenshtein';
requires 'Unicode::Normalize';

on 'test' => sub {
    requires 'File::Spec';
    requires 'File::Temp';
    requires 'Test::More';
};