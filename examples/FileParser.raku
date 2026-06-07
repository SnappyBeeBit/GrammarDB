role GrammarDB::Action {}

class GrammarDB::Engine {
	has Str $.db-file;
	has %.database;
	method parse-by-line (Grammar $grammar, GrammarDB::Action $actions) {
		for $.db-file.IO.lines  {
			my Match $match = $grammar.subparse($_, :actions($actions));
			if $match {
				say "Extracted: {$match.made}";
			}
			
		}
	}
}

class MarkdownHeaderParserActions does GrammarDB::Action {
	method TOP($/) {
		make ~$<alpha>.join("");
	}
}


grammar MarkdownHeaderParser {
    token TOP { '#'+ \s <alpha>+ }
}

my $fileparse = GrammarDB::FileParser.new(file-name => "testfile.md");
$fileparse.parse-by-line(MarkdownHeaderParser, MarkdownHeaderParserActions);
