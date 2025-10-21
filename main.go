package main

import (
	"fmt"
	"os"
	"os/signal"
	"sync"
	"time"

	probing "github.com/prometheus-community/pro-bing"
)

func main() {
	
	var targets []*Target
	targets = append(targets, &Target{Host: "www.google.com", Iface: "", Count: -1, Size: 24, TTL: 64, Timeout: time.Second*100000, Interval: time.Second})
	targets = append(targets, &Target{Host: "localhost", Iface: "", Count: -1, Size: 24, TTL: 64, Timeout: time.Second*100000, Interval: time.Second})

	monitor(targets)
}

type Target struct {
	Host     string
	Iface    string
	Count    int
	Size     int
	TTL      int
	Timeout  time.Duration
	Interval time.Duration
}

func monitor(targets []*Target) {
	var wg sync.WaitGroup

	for _, t := range targets {
		wg.Go(func() {
			err := t.Probe()
			if err != nil {
				fmt.Fprintf(os.Stderr, "probe failed for %s: %v\n", t.Host, err)
			}
		})
	}
	wg.Wait()
}

func (t *Target) Probe() error {
	pinger, err := probing.NewPinger(t.Host)
	if err != nil {
		return err
	}

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		for range c {
			pinger.Stop()
		}
	}()

	pinger.InterfaceName = t.Iface
	pinger.Count = t.Count
	pinger.Size = t.Size
	pinger.TTL = t.TTL
	pinger.Timeout = t.Timeout
	pinger.Interval = t.Interval

	pinger.OnRecv = func(pkt *probing.Packet) {
		fmt.Printf("%d bytes from %s icmp_seq=%d time=%v ttl=%v\n",
			pkt.Nbytes, pkt.IPAddr, pkt.Seq, pkt.Rtt, pkt.TTL)
	}

	pinger.OnDuplicateRecv = func(pkt *probing.Packet) {
		fmt.Printf("%d bytes from %s icmp_seq=%d time=%v ttl=%v (DUP!)\n",
			pkt.Nbytes, pkt.IPAddr, pkt.Seq, pkt.Rtt, pkt.TTL)
	}

	pinger.OnFinish = func(stats *probing.Statistics) {
		fmt.Printf("\n--- %s ping statistics ---\n", stats.Addr)
		fmt.Printf("%d packets transmitted, %d packets received, %d duplicates, %v%% packet loss\n",
			stats.PacketsSent, stats.PacketsRecv, stats.PacketsRecvDuplicates, stats.PacketLoss)
		fmt.Printf("round-trip min/avg/max/stddev = %v/%v/%v/%v\n",
			stats.MinRtt, stats.AvgRtt, stats.MaxRtt, stats.StdDevRtt)
	}

	fmt.Printf("Ping %s (%s):\n", pinger.Addr(), pinger.IPAddr())
	err = pinger.Run()
	if err != nil {
		return err
	}

	return err
}

func ping(host string) {
	pinger, err := probing.NewPinger(host)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		for range c {
			pinger.Stop()
		}
	}()

	pinger.OnRecv = func(pkt *probing.Packet) {
		fmt.Printf("%d bytes from %s icmp_seq=%d time=%v ttl=%v\n",
			pkt.Nbytes, pkt.IPAddr, pkt.Seq, pkt.Rtt, pkt.TTL)
	}

	pinger.OnDuplicateRecv = func(pkt *probing.Packet) {
		fmt.Printf("%d bytes from %s icmp_seq=%d time=%v ttl=%v (DUP!)\n",
			pkt.Nbytes, pkt.IPAddr, pkt.Seq, pkt.Rtt, pkt.TTL)
	}

	pinger.OnFinish = func(stats *probing.Statistics) {
		fmt.Printf("\n--- %s ping statistics ---\n", stats.Addr)
		fmt.Printf("%d packets transmitted, %d packets received, %d duplicates, %v%% packet loss\n",
			stats.PacketsSent, stats.PacketsRecv, stats.PacketsRecvDuplicates, stats.PacketLoss)
		fmt.Printf("round-trip min/avg/max/stddev = %v/%v/%v/%v\n",
			stats.MinRtt, stats.AvgRtt, stats.MaxRtt, stats.StdDevRtt)
	}

	fmt.Printf("Ping %s (%s):\n", pinger.Addr(), pinger.IPAddr())
	err = pinger.Run()
	if err != nil {
		fmt.Println("failed to ping target host:", err)
	}
}
