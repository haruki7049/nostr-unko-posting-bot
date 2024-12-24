use clap::Parser;
use nostr_sdk::{
    Client, Event, EventBuilder, Filter, Keys, Kind, Metadata, Options, PublicKey, SecretKey,
    ToBech32, Url,
};

#[derive(Debug, Parser)]
#[command(version, about)]
struct CommandLineArguments {
    secret_key: String,
    public_key: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: CommandLineArguments = CommandLineArguments::parse();

    tracing_subscriber::fmt::init();

    let keys = Keys::parse(&args.secret_key)?;
    let client = Client::builder()
        .signer(keys.clone())
        .opts(Options::new().gossip(true))
        .build();

    println!("Bot public key: {}", keys.public_key().to_bech32()?);

    client.add_relay("wss://nostr.oxtr.dev").await?;
    client.add_relay("wss://relay.damus.io").await?;
    client.add_relay("wss://nostr.mom").await?;
    client.add_relay("wss://nostr.wine").await?;
    client.add_relay("wss://relay.nostr.info").await?;
    client.add_relay("wss://auth.nostr1.com").await?;

    client.connect().await;

    let metadata = Metadata::new()
        .name("unkobot")
        .about("This bot says 'Unko!!'. authored by https://github.com/haruki7049")
        .website(Url::parse("https://github.com/haruki7049/nostr-unko-posting-bot")?)
        .display_name("Unko Bot");
    client.set_metadata(&metadata).await?;

    let subscription = Filter::new()
        .pubkey(keys.public_key())
        .kind(Kind::GiftWrap)
        .limit(0); // Limit set to 0 to get only new events! Timestamp::now() CAN'T be used for gift wrap since the timestamps are tweaked!

    client.subscribe(vec![subscription], None).await?;

    let event: Event = EventBuilder::new(Kind::TextNote, "Unko!!")
        .build(PublicKey::parse(&args.public_key)?)
        .sign_with_keys(&Keys::new(SecretKey::parse(&args.secret_key)?))?;

    client.send_event(event).await?;

    Ok(())
}
