
package EST::Base;


use warnings;
use strict;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};

    $self->{db_version} = exists $args{db_version} ? $args{db_version} : 0;

    return bless($self, $class);
}


# Returns a hashmap of the sequence IDs in the input.  It is a hashmap
# that maps UniProt ID (or UniRef cluster ID, depending on configuration) to
# optional metadata.  The hash value is a array ref, which can be empty.  If it
# is not empty, it contains a list of domains that the sequence ID has for
# specific family inputs.  For FASTA, BLAST, and Accession results, this should
# be empty.
sub getSequenceIds {
    my $self = shift;
    return {};
}


sub getMetadata {
    my $self = shift;
    return {};
}


sub getStatistics {
    my $self = shift;
    return {};
}


sub dbSupportsFragment {
    my $self = shift;
    return $self->{db_version} > 1;
}


sub flattenTaxSearch {
    my $taxSearch = shift;
    my @cond;
    foreach my $cat (keys %$taxSearch) {
        my $vals = $taxSearch->{$cat};
        map { push @cond, "$cat LIKE '\%$_\%'" } @$vals;
    }
    my $where = join(" OR ", @cond);
    return $where;
}


sub excludeIds {
    my $self = shift;
    my $ids = shift;

    my %full;

    my $fragmentWhere = $self->{config}->{exclude_fragments} ? "AND Fragment = 0" : "";
    my $taxWhere = $self->{config}->{tax_search} ? (" AND (" . EST::Base::flattenTaxSearch($self->{config}->{tax_search}) . ")") : "";
    my $taxJoin = $self->{config}->{tax_search} ? "LEFT JOIN taxonomy ON annotations.Taxonomy_ID = taxonomy.Taxonomy_ID" : "";

    my @ids = keys %$ids;
    my $batchSize = 20;
    while (scalar @ids) {
        my @group = splice(@ids, 0, $batchSize);
        my $whereIds = join(",", map { "'$_'" } @group);
        my $sql = "SELECT accession FROM annotations $taxJoin WHERE accession IN ($whereIds) $fragmentWhere $taxWhere";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            $full{$row->{accession}} = $ids->{$row->{accession}};
        }
    }

    return \%full;
}


1;

