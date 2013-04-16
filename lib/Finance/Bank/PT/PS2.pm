package Finance::Bank::PT::PS2;

use strict;
use warnings;

use Data::Dumper;
use Carp;

# VERSION
# ABSTRACT: Helper for generating PS2 files used for automatic transactions in banking systems.

# This method creates a new object and define several format specific parameters of PS2 files (e.g. filler with zeros)
sub new {
    my $c      = shift;
    my %params = @_;

    $params{'debug'} ||= 0;

    my $s = bless {%params}, $c;

    $s->{'file_ref'} = 'PS2';

    $s->{'account_situation'} = '00';

    $s->{'record_situation'} = '0';

    $s->{'initial_record'} = {
        'record_type' => '1',
        'filler'      => '0000000000000000000',
    };

    $s->{'trans'} = {
        'record_type' => '2',
        'filler'      => '00',
    };

    $s->{'final_record'} = {
        'record_type' => '9',
        'filler1'     => '00',
        'filler2'     => '000000',
        'filler3'     => '00000000000000000000000000000000000000',
    };

    return $s;
}

# To be the first method called
# defines the code that determines the service in question (salaries payment, bank transfer, house rent, ...)
# e.g.
#       'operation_type' => '08'
#
sub set_operation_type {
    my $self = shift;
    my %args = @_;

    ( length( $args{'operation_type'} ) == 2 )
        || croak 'Invalid size of operation type!';
    $self->{'operation_type'} = $args{'operation_type'};
    return;
}

# Method used to obtain the corresponding hash key of a transaction (register type 2)
sub get_transaction_key {
    my $self      = shift;
    my $num_trans = shift;

    return sprintf( 'trans%s', $num_trans );
}

# To be called after the set_operation_type() method
# set the necessary fields to build the start register (register type 1)
# e.g.
#       'owner_nib'       => '123456789012345678901',
#       'currency_code'   => 'EUR',
#       'processing_date' => '20120314',                 #AAAAMMDD
#       'owner_ref'       => 'Owner NAME ',
#
sub set_initial_record {
    my $self = shift;
    my %args = @_;

    ( length( $args{'owner_nib'} ) == 21 )
        || croak 'Invalid size of owner´s NIB!';
    $self->{'initial_record'}->{'owner_nib'} = $args{'owner_nib'};

    ( length( $args{'currency_code'} ) == 3 )
        || croak 'Invalid size of currency code!';
    $self->{'initial_record'}->{'currency_code'} = $args{'currency_code'};

    ( length( $args{'processing_date'} ) == 8 )
        || croak 'Invalid size of processing date!';
    $self->{'initial_record'}->{'processing_date'} = $args{'processing_date'};

    ( length( $args{'owner_ref'} ) <= 20 )
        || croak 'Invalid size of owner´s reference!';

    while ( length( $args{'owner_ref'} ) < 20 ) {
        $args{'owner_ref'} .= q{ };
    }

    $self->{'initial_record'}->{'owner_ref'} = $args{'owner_ref'};

    return;
}

# To be called after the set_operation_type() and set_initial_record() methods
# set the necessary fields to build a transaction register (register type 2)
# This method is called n times where n is the number of transactions
# e.g.
#       'nib'          => '098765432123456789098',
#       'amount'       => 10123,                         #101,23 €
#       'company_ref'  => 'NAME OF THE COMPANY or PERSON',
#       'transfer_ref' => 'april/2012',
#
sub add_transaction {
    my $self = shift;
    my $t    = shift;

    $self->{'num_trans'} ||= 0;

    $self->{'num_trans'}++;

    my $transaction_key = $self->get_transaction_key( $self->{'num_trans'} );

    ( length( $t->{'nib'} ) == 21 )
        || croak
        "Invalid size of destination NIB in transaction $self->{'num_trans'} !";

    $self->{$transaction_key}->{'nib'} = $t->{'nib'};

    ( length( $t->{'amount'} ) <= 13 )
        || croak "Invalid size of amount in transaction $self->{'num_trans'}!";

    while ( length( $t->{'amount'} ) < 13 ) {
        $t->{'amount'} = '0' . $t->{'amount'};
    }

    $self->{$transaction_key}->{'amount'} = $t->{'amount'};

    ( length( $t->{'company_ref'} ) <= 20 )
        || croak
        "Invalid size of company_ref in transaction $self->{'num_trans'}!";

    while ( length( $t->{'company_ref'} ) < 20 ) {
        $t->{'company_ref'} .= q{ };
    }

    $self->{$transaction_key}->{'company_ref'} = $t->{'company_ref'};

    ( length( $t->{'transfer_ref'} ) <= 15 )
        || croak
        "Invalid size of transfer_ref in transaction $self->{'num_trans'}!";

    while ( length( $t->{'transfer_ref'} ) < 15 ) {
        $t->{'transfer_ref'} .= q{ };
    }

    $self->{$transaction_key}->{'transfer_ref'} = $t->{'transfer_ref'};

    return;

}

# To be called after adding all the transactions with the method add_transaction()
# set the necessary fields to build the end register (register type 9)
sub set_final_record {
    my $self = shift;
    my %args = @_;

    my $total_transactions = $self->{'num_trans'};

   ( length( $total_transactions ) <= 14 )
        || croak 'Invalid size of total number of transactions!';

    while ( length( $total_transactions ) < 14 ) {
        $total_transactions = '0' . $total_transactions;
    }

    $self->{'final_record'}->{'num_trans_total'} = $total_transactions;

    my $total_amount = 0;

    for my $i ( 1 .. $self->{'num_trans'} ) {
        my $transaction_key = $self->get_transaction_key( $i );
        $total_amount += $self->{$transaction_key}->{'amount'};
    }

    ( length( $total_amount ) <= 13 )
        || croak 'Invalid size of total amount!';

    while ( length( $total_amount ) < 13 ) {
        $total_amount = '0' . $total_amount;
    }

    $self->{'final_record'}->{'amount_trans_total'} = $total_amount;

    return;
}

# This method builds the start register (register type 1) as a string
sub init_rec_as_string {
    my $self = shift;

    my $string = sprintf(
        "%s%s%s%s%s%s%s%s%s%s\r\n",
        $self->{'file_ref'},
        $self->{'initial_record'}->{'record_type'},
        $self->{'operation_type'},
        $self->{'account_situation'},
        $self->{'record_situation'},
        $self->{'initial_record'}->{'owner_nib'},
        $self->{'initial_record'}->{'currency_code'},
        $self->{'initial_record'}->{'processing_date'},
        $self->{'initial_record'}->{'owner_ref'},
        $self->{'initial_record'}->{'filler'}
    );

    return $string;

}

# This method builds the transaction registers (registers type 2) as a string
sub trans_as_string {
    my $self = shift;

    my $string = q{};
    for my $i ( 1 .. $self->{'num_trans'} ) {

        my $transaction_key = $self->get_transaction_key( $i );

        my $aux = sprintf(
            "%s%s%s%s%s%s%s%s%s%s\r\n",
            $self->{'file_ref'},
            $self->{'trans'}->{'record_type'},
            $self->{'operation_type'},
            $self->{'account_situation'},
            $self->{'record_situation'},
            $self->{$transaction_key}->{'nib'},
            $self->{$transaction_key}->{'amount'},
            $self->{$transaction_key}->{'company_ref'},
            $self->{$transaction_key}->{'transfer_ref'},
            $self->{'trans'}->{'filler'}
        );

        $self->{$transaction_key}->{'string_len'} = length $aux;

        $string .= $aux;

    }

    return $string;

}

# This method builds the end register (register type 9) as a string
sub final_rec_as_string {
    my $self = shift;

    my $string = sprintf(
        '%s%s%s%s%s%s%s%s%s',
        $self->{'file_ref'},
        $self->{'final_record'}->{'record_type'},
        $self->{'operation_type'},
        $self->{'final_record'}->{'filler1'},
        $self->{'record_situation'},
        $self->{'final_record'}->{'filler2'},
        $self->{'final_record'}->{'num_trans_total'},
        $self->{'final_record'}->{'amount_trans_total'},
        $self->{'final_record'}->{'filler3'}
    );

    return $string;
}

# To be called after the set_initial_record(), add_transaction() (n times where n is the number of transactions) and set_final_record() methods
# this method builds the content of the PS2 file as a string
sub as_string {
    my $self = shift;

    my $begin = $self->init_rec_as_string();
    my $trans = $self->trans_as_string();
    my $final = $self->final_rec_as_string();

    $self->{'initial_record'}->{'string_len'} = length $begin;
    $self->{'trans'}->{'string_len'}          = length $trans;
    $self->{'final_record'}->{'string_len'}   = length $final;

    return $begin . $trans . $final;

}

1;
__END__

=head1 SYNOPSIS

Helper for generating PS2 files used for automatic transactions in banking systems.

=head1 DESCRIPTION

This class helps generating PS2 files used for automatic transactions in banking systems.
PS2 files have a structure based in 3 different register formats with a fixed length of 80 bytes:

      Register type 1 --> start register          --> one per file
          - operation type, owner´s NIB, currency code (e.g. EUR), processing date, owner´s reference

      Register type 2 --> transaction register    --> one or more per file
          - operation type, destination NIB, amount, company´s reference, transaction´s reference

      Register type 9 --> end register            --> one per file
          - operation type, total transactions, total amount

For more detailed description of PS2 files: https://corp.millenniumbcp.pt/pt/private/Documents/Layout_PS2_3.pdf (PT)

=head1 METHODS

=head2 set_operation_type

The first method called
defines the code that determines the service in question (salaries payment, bank transfer, house rent, ...)
e.g.
      'operation_type' => '08'

=head2 get_transaction_key

Method used to obtain the corresponding hash key of a transaction (register type 2)

=head2 set_initial_record

To be called after the set_operation_type() method
set the necessary fields to build the start register (register type 1)
e.g.
      'owner_nib'       => '123456789012345678901',
      'currency_code'   => 'EUR',
      'processing_date' => '20120314',                 #AAAAMMDD
      'owner_ref'       => 'Owner NAME ',



=head2 add_transaction

To be called after the set_operation_type() and set_initial_record() methods
set the necessary fields to build a transaction register (register type 2)
This method is called n times where n is the number of transactions
e.g.
      'nib'          => '098765432123456789098',
      'amount'       => 10123,                         #101,23 €
      'company_ref'  => 'NAME OF THE COMPANY or PERSON',
      'transfer_ref' => 'april/2012',

=head2 set_final_record

To be called after adding all the transactions with the method add_transaction()
set the necessary fields to build the end register (register type 9)


=head2 init_rec_as_string

This method builds the start register (register type 1) as a string

=head2 trans_as_string

This method builds the transaction registers (registers type 2) as a string

=head2 final_rec_as_string

This method builds the end register (register type 9) as a string

=head2 as_string

To be called after the set_initial_record(), add_transaction() (n times where n is the number of transactions) and set_final_record() methods
this method builds the content of the PS2 file as a string
