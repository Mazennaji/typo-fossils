requires 'perl', '5.020';
requires 'Encode';
requires 'File::Basename';
requires 'File::Find';
requires 'File::Path';
requires 'FindBin';
requires 'Getopt::Long';
requires 'JSON::PP';
requires 'List::Util';
requires 'Text::Levenshtein';
requires 'Unicode::Normalize';

on 'test' => sub {
    requires 'File::Spec';
    requires 'File::Temp';
    requires 'Test::More';
};