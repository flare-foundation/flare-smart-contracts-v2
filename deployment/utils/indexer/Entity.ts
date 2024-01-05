import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryColumn,
  PrimaryGeneratedColumn,
} from "typeorm";

// Name of the transaction table in FTL project
@Entity("transactions")
export class TLPTransaction {
  @PrimaryGeneratedColumn({ type: "int" })
  id!: number;

  @Column()
  @Index({ unique: true })
  hash!: string;

  @Column()
  @Index({ unique: false })
  function_sig!: string;

  @Column()
  input!: string;

  @Column()
  block_number!: number;

  @Column()
  block_hash!: string;

  @Column()
  transaction_index!: number;

  @Column()
  from_address!: string;

  @Column()
  to_address!: string;

  @Column()
  status!: number;

  @Column()
  value!: string;

  @Column()
  gas_price!: string;

  @Column()
  gas!: number;

  @Column()
  @Index({ unique: false })
  timestamp!: number;

  @OneToMany(() => TLPEvents, event => event.transaction_id)
  TPLEvents_set!: TLPEvents[];
}

// Name of the event table in FTL project
@Entity("logs")
export class TLPEvents {
  @PrimaryGeneratedColumn({ type: "int" })
  id!: number;

  @ManyToOne(type => TLPTransaction, transaction_id => transaction_id.TPLEvents_set)
  @JoinColumn({ name: "transaction_id" })
  @Index()
  transaction_id!: TLPTransaction;

  @Column()
  address!: string;

  @Column()
  data!: string;

  @Column()
  topic0!: string;

  @Column()
  topic1!: string;

  @Column()
  topic2!: string;

  @Column()
  topic3!: string;

  @Column()
  log_index!: number;

  @Column()
  @Index()
  timestamp!: number;
}

export type ITLPTransaction = new () => TLPTransaction;
export type ITLPEvents = new () => TLPEvents;

@Entity("states")
export class TLPState {
  @PrimaryColumn()
  id!: number;

  @Column({ length: 50, nullable: true })
  @Index()
  name: string = "";

  @Column({ unsigned: true })
  index: number = 0;

  @Column({ unsigned: true })
  block_timestamp: number = 0;

  @Column({ type: "datetime", precision: 3, nullable: true })
  updated: Date = new Date();
}

export type ITPLState = new () => TLPState;
